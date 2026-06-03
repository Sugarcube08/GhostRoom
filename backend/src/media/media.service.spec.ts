import { Test, TestingModule } from "@nestjs/testing";
import { MediaService } from "./media.service";
import { ConfigService } from "@nestjs/config";
import { getSignedUrl } from "@aws-sdk/s3-request-presigner";
import { getRepositoryToken } from "@nestjs/typeorm";
import { MediaEntity } from "./entities/media.entity";
import { AuditService } from "../audit/audit.service";
import { describe, expect, it, jest, beforeEach } from "@jest/globals";

jest.mock("@aws-sdk/s3-request-presigner");
jest.mock("@aws-sdk/client-s3");

describe("MediaService", () => {
  let service: MediaService;
  let mockRedis: any;
  let mockMediaRepo: any;
  let mockAuditService: any;

  beforeEach(async () => {
    mockRedis = {
      pipeline: jest.fn().mockReturnValue({
        incrby: jest.fn().mockReturnThis(),
        incr: jest.fn().mockReturnThis(),
        expire: jest.fn().mockReturnThis(),
        exec: (jest.fn() as any).mockResolvedValue([]),
      }),
      get: (jest.fn() as any).mockResolvedValue(null),
    };

    mockMediaRepo = {
      create: jest.fn().mockImplementation((entity) => entity),
      save: (jest.fn() as any).mockResolvedValue({}),
      findOne: (jest.fn() as any).mockResolvedValue({
        owner_id: "alice",
        state: "UPLOADING",
      }),
      delete: (jest.fn() as any).mockResolvedValue({}),
      find: (jest.fn() as any).mockResolvedValue([]),
    };

    mockAuditService = {
      log: (jest.fn() as any).mockResolvedValue(undefined),
    };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        MediaService,
        {
          provide: ConfigService,
          useValue: {
            get: jest.fn().mockImplementation((key) => {
              if (key === "R2_ACCOUNT_ID") return "test-account";
              return null;
            }),
          },
        },
        {
          provide: "REDIS_CLIENT",
          useValue: mockRedis,
        },
        {
          provide: getRepositoryToken(MediaEntity),
          useValue: mockMediaRepo,
        },
        {
          provide: AuditService,
          useValue: mockAuditService,
        },
      ],
    }).compile();

    service = module.get<MediaService>(MediaService);
  });

  it("should be defined", () => {
    expect(service).toBeDefined();
  });

  describe("generateUploadUrl", () => {
    it("should return a signed URL and store metadata in Postgres", async () => {
      (getSignedUrl as any).mockResolvedValue("http://signed-put-url");

      const result = await service.generateUploadUrl(
        "alice",
        1024,
        "image/jpeg",
        "some-hash",
      );

      expect(result.mediaId).toBeDefined();
      expect(result.uploadUrl).toBe("http://signed-put-url");
      expect(mockMediaRepo.create).toHaveBeenCalledWith(
        expect.objectContaining({
          owner_id: "alice",
          state: "UPLOADING",
        }),
      );
      expect(mockAuditService.log).toHaveBeenCalledWith(
        "media_upload_requested",
        expect.any(Object),
      );
    });

    it("should rewrite URL host when dynamicPublicEndpoint is provided", async () => {
      (getSignedUrl as any).mockResolvedValue(
        "http://minio:9000/ghostroom-media/media/123?Signature=abc",
      );

      const result = await service.generateUploadUrl(
        "alice",
        1024,
        "image/jpeg",
        "some-hash",
        "http://192.168.1.100:9000",
      );

      expect(result.uploadUrl).toBe(
        "http://192.168.1.100:9000/ghostroom-media/media/123?Signature=abc",
      );
    });
  });

  describe("reference counts", () => {
    it("should increment reference count and reset state to REFERENCED", async () => {
      const mockMeta = {
        id: "media-id",
        reference_count: 1,
        state: "UPLOADED",
        expires_at: new Date(),
      };
      mockMediaRepo.findOne.mockResolvedValue(mockMeta);

      await service.incrementReferenceCount("media-id");

      expect(mockMeta.reference_count).toBe(2);
      expect(mockMeta.state).toBe("REFERENCED");
      expect(mockMeta.expires_at).toBeNull();
      expect(mockMediaRepo.save).toHaveBeenCalledWith(mockMeta);
    });

    it("should decrement reference count and mark as ORPHANED when hitting 0", async () => {
      const mockMeta = {
        id: "media-id",
        reference_count: 1,
        state: "REFERENCED",
        expires_at: null,
      };
      mockMediaRepo.findOne.mockResolvedValue(mockMeta);

      await service.decrementReferenceCount("media-id");

      expect(mockMeta.reference_count).toBe(0);
      expect(mockMeta.state).toBe("ORPHANED");
      expect(mockMeta.expires_at).toBeInstanceOf(Date);
      expect(mockAuditService.log).toHaveBeenCalledWith("MEDIA_ORPHANED", {
        media_id: "media-id",
      });
      expect(mockAuditService.log).toHaveBeenCalledWith(
        "MEDIA_DELETE_SCHEDULED",
        expect.any(Object),
      );
      expect(mockMediaRepo.save).toHaveBeenCalledWith(mockMeta);
    });
  });
});
