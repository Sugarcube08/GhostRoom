import { Test, TestingModule } from "@nestjs/testing";
import { InboxService } from "./inbox.service";
import { ConfigService } from "@nestjs/config";
import { getRepositoryToken } from "@nestjs/typeorm";
import { MessageEntity } from "./entities/message.entity";
import { DeliveryEntity } from "./entities/delivery.entity";
import { DeviceEntity } from "./entities/device.entity";
import { MediaService } from "../media/media.service";
import { FirebaseService } from "./firebase.service";
import { describe, expect, it, jest, beforeEach } from "@jest/globals";

describe("InboxService", () => {
  let service: InboxService;
  let mockRedis: any;
  let mockMessageRepo: any;
  let mockDeliveryRepo: any;

  beforeEach(async () => {
    mockRedis = {
      pipeline: jest.fn().mockReturnValue({
        setex: jest.fn().mockReturnThis(),
        zadd: jest.fn().mockReturnThis(),
        zremrangebyrank: jest.fn().mockReturnThis(),
        expire: jest.fn().mockReturnThis(),
        zrem: jest.fn().mockReturnThis(),
        del: jest.fn().mockReturnThis(),
        exec: (jest.fn() as any).mockResolvedValue([]),
      }),
      zrangebyscore: (jest.fn() as any).mockResolvedValue([]),
      mget: (jest.fn() as any).mockResolvedValue([]),
      zrem: (jest.fn() as any).mockResolvedValue(0),
      setex: (jest.fn() as any).mockResolvedValue("OK"),
      get: (jest.fn() as any).mockResolvedValue(null),
      del: (jest.fn() as any).mockResolvedValue(1),
    };

    mockMessageRepo = {
      create: jest.fn().mockImplementation((entity) => entity),
      save: (jest.fn() as any).mockResolvedValue({}),
      find: (jest.fn() as any).mockResolvedValue([]),
      findOne: (jest.fn() as any).mockResolvedValue({
        id: "msg-id",
        retention_mode: "PERSISTENT",
      }),
      delete: (jest.fn() as any).mockResolvedValue({}),
    };

    mockDeliveryRepo = {
      create: jest.fn().mockImplementation((entity) => entity),
      save: (jest.fn() as any).mockResolvedValue({}),
      find: (jest.fn() as any).mockResolvedValue([]),
      update: (jest.fn() as any).mockResolvedValue({}),
      count: (jest.fn() as any).mockResolvedValue(0),
      findOne: (jest.fn() as any).mockResolvedValue({
        sender_id: "sender-id",
        status: "PENDING",
      }),
      delete: (jest.fn() as any).mockResolvedValue({}),
    };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        InboxService,
        {
          provide: FirebaseService,
          useValue: {
            sendWakeup: (jest.fn() as any).mockResolvedValue("test-msg-id"),
            getFcmEnabled: jest.fn().mockReturnValue(true),
            getApp: jest.fn().mockReturnValue({}),
            getProjectId: jest.fn().mockReturnValue("test-project-id"),
            getCredentialSource: jest.fn().mockReturnValue("env_vars"),
          },
        },
        {
          provide: ConfigService,
          useValue: {
            get: jest.fn().mockReturnValue(null),
          },
        },
        {
          provide: "REDIS_CLIENT",
          useValue: mockRedis,
        },
        {
          provide: getRepositoryToken(MessageEntity),
          useValue: mockMessageRepo,
        },
        {
          provide: getRepositoryToken(DeliveryEntity),
          useValue: mockDeliveryRepo,
        },
        {
          provide: getRepositoryToken(DeviceEntity),
          useValue: {
            findOne: (jest.fn() as any).mockResolvedValue(null),
            save: (jest.fn() as any).mockResolvedValue({}),
          },
        },
        {
          provide: MediaService,
          useValue: {
            incrementReferenceCount: jest
              .fn()
              .mockImplementation(async () => {}),
            decrementReferenceCount: jest
              .fn()
              .mockImplementation(async () => {}),
          },
        },
      ],
    }).compile();

    service = module.get<InboxService>(InboxService);
  });

  it("should be defined", () => {
    expect(service).toBeDefined();
  });

  describe("queueMessage", () => {
    it("should store message in Postgres and Redis", async () => {
      mockMessageRepo.findOne.mockResolvedValue(null);
      const publicId = "test-id";
      const payload = { id: "msg-id", n: "nonce", c: "ciphertext" };

      const envelope = await service.queueMessage(publicId, payload);

      expect(envelope).toBeDefined();
      expect(mockMessageRepo.create).toHaveBeenCalled();
      expect(mockMessageRepo.save).toHaveBeenCalled();
      expect(mockRedis.pipeline).toHaveBeenCalled();
    });
  });

  describe("acknowledgeMessage", () => {
    it("should update delivered_at for PERSISTENT messages", async () => {
      mockDeliveryRepo.find.mockResolvedValue([
        { status: "ACKNOWLEDGED" }
      ]);
      await service.acknowledgeMessage("test-id", "msg-id");

      expect(mockMessageRepo.findOne).toHaveBeenCalled();
      expect(mockMessageRepo.save).toHaveBeenCalled(); // Since it's PERSISTENT in mock
      expect(mockDeliveryRepo.save).toHaveBeenCalled();
    });

    it("should delete VIEW_ONCE messages", async () => {
      mockMessageRepo.findOne.mockResolvedValue({
        id: "msg-id",
        retention_mode: "VIEW_ONCE",
      });
      mockDeliveryRepo.find.mockResolvedValue([
        { status: "ACKNOWLEDGED" }
      ]);
      await service.acknowledgeMessage("test-id", "msg-id");

      expect(mockMessageRepo.delete).toHaveBeenCalledWith("msg-id");
    });
  });
});
