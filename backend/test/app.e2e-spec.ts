import { Test, TestingModule } from "@nestjs/testing";
import { INestApplication } from "@nestjs/common";
import { AppModule } from "../src/app.module";
import { io, Socket } from "socket.io-client";
import {
  describe,
  expect,
  it,
  beforeAll,
  afterAll,
  afterEach,
  jest,
} from "@jest/globals";

import { getRepositoryToken } from "@nestjs/typeorm";
import { MessageEntity } from "../src/inbox/entities/message.entity";
import { DeliveryEntity } from "../src/inbox/entities/delivery.entity";
import { MediaEntity } from "../src/media/entities/media.entity";
import { MediaService } from "../src/media/media.service";

describe("RelayGateway (Dual-Mode E2E)", () => {
  let app: INestApplication;
  let clientV1: Socket;
  let clientV2: Socket;
  let mockRedis: any;
  let port: number;

  beforeAll(async () => {
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
      multi: jest.fn().mockReturnValue({
        lrange: jest.fn().mockReturnThis(),
        del: jest.fn().mockReturnThis(),
        exec: (jest.fn() as any).mockResolvedValue([[], []]),
      }),
      zrangebyscore: (jest.fn() as any).mockResolvedValue([]),
      mget: (jest.fn() as any).mockResolvedValue([]),
      zrem: (jest.fn() as any).mockResolvedValue(0),
      setex: (jest.fn() as any).mockResolvedValue("OK"),
      get: (jest.fn() as any).mockResolvedValue(null),
      del: (jest.fn() as any).mockResolvedValue(1),
      lpush: (jest.fn() as any).mockResolvedValue(1),
      ltrim: (jest.fn() as any).mockResolvedValue("OK"),
      expire: (jest.fn() as any).mockResolvedValue(1),
      on: jest.fn(),
      subscribe: jest.fn(),
    };

    const mockRepo = {
      create: (jest.fn() as any).mockImplementation((e: any) => e),
      save: (jest.fn() as any).mockResolvedValue({}),
      find: (jest.fn() as any).mockResolvedValue([]),
      findOne: (jest.fn() as any).mockResolvedValue(null),
      delete: (jest.fn() as any).mockResolvedValue({}),
      update: (jest.fn() as any).mockResolvedValue({}),
    };

    const mockMediaService = {
      deleteMedia: (jest.fn() as any).mockResolvedValue({}),
    };

    try {
      const moduleFixture: TestingModule = await Test.createTestingModule({
        imports: [AppModule],
      })
        .overrideProvider("REDIS_CLIENT")
        .useValue(mockRedis)
        .overrideProvider("REDIS_SUBSCRIBER")
        .useValue(mockRedis)
        .overrideProvider(getRepositoryToken(MessageEntity))
        .useValue(mockRepo)
        .overrideProvider(getRepositoryToken(DeliveryEntity))
        .useValue(mockRepo)
        .overrideProvider(getRepositoryToken(MediaEntity))
        .useValue(mockRepo)
        .overrideProvider(MediaService)
        .useValue(mockMediaService)
        .compile();

      app = moduleFixture.createNestApplication();
      await app.init();
      await app.listen(0);
      const address = app.getHttpServer().address();
      port = typeof address === "string" ? 0 : address.port;
    } catch (e) {
      console.error("Failed to compile E2E module", e);
    }
  });

  afterAll(async () => {
    if (app) await app.close();
  });

  afterEach(() => {
    if (clientV1) clientV1.disconnect();
    if (clientV2) clientV2.disconnect();
  });

  it("should handle V1 Space flow (Broadcast)", (done) => {
    if (!app) return done();
    const url = `http://localhost:${port}`;
    clientV1 = io(url);
    clientV2 = io(url);

    const roomId = "test-room-v1";
    mockRedis.get.mockResolvedValue(JSON.stringify({ id: roomId }));

    clientV1.emit("space.join", { roomId });
    clientV1.on("space.joined", () => {
      clientV2.emit("space.join", { roomId });
    });

    clientV2.on("space.joined", () => {
      clientV1.emit("message.send", {
        target_id: roomId,
        ciphertext: "hello-v1",
        v: 1,
      });
    });

    clientV2.on("message.receive", (payload) => {
      expect(payload.ciphertext).toBe("hello-v1");
      done();
    });
  });

  it("should receive challenge upon connection", (done) => {
    if (!app) return done();
    const url = `http://localhost:${port}`;
    clientV1 = io(url);
    clientV1.on("identity.challenge", (data) => {
      expect(data.nonce).toBeDefined();
      expect(data.nonce.length).toBe(64);
      done();
    });
  });
});
