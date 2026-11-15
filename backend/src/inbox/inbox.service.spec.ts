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
  let mockMessageRepo: any;
  let mockDeliveryRepo: any;

  beforeEach(async () => {
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
    it("should store message in Postgres", async () => {
      mockMessageRepo.findOne.mockResolvedValue(null);
      const publicId = "test-id";
      const payload = { id: "msg-id", n: "nonce", c: "ciphertext" };

      const envelope = await service.queueMessage(publicId, payload);

      expect(envelope).toBeDefined();
      expect(mockMessageRepo.create).toHaveBeenCalled();
      expect(mockMessageRepo.save).toHaveBeenCalled();
    });
  });

  describe("acknowledgeMessage", () => {
    it("should purge message from database once all deliveries are acknowledged (store-and-forward)", async () => {
      mockMessageRepo.findOne.mockResolvedValue({
        id: "msg-id",
        retention_mode: "PERSISTENT",
      });
      mockDeliveryRepo.find.mockResolvedValue([
        { status: "ACKNOWLEDGED" }
      ]);
      await service.acknowledgeMessage("test-id", "msg-id");

      expect(mockMessageRepo.findOne).toHaveBeenCalled();
      expect(mockMessageRepo.delete).toHaveBeenCalledWith("msg-id");
      expect(mockDeliveryRepo.delete).toHaveBeenCalledWith({ message_id: "msg-id" });
    });

    it("should decrement media refcount if message has media_id upon deletion", async () => {
      mockMessageRepo.findOne.mockResolvedValue({
        id: "msg-id",
        media_id: "media-123",
      });
      mockDeliveryRepo.find.mockResolvedValue([
        { status: "ACKNOWLEDGED" }
      ]);
      await service.acknowledgeMessage("test-id", "msg-id");

      expect(mockMessageRepo.delete).toHaveBeenCalledWith("msg-id");
      expect(mockDeliveryRepo.delete).toHaveBeenCalledWith({ message_id: "msg-id" });
    });
  });
});
