import {
  WebSocketGateway,
  WebSocketServer,
  SubscribeMessage,
  OnGatewayConnection,
  OnGatewayDisconnect,
} from "@nestjs/websockets";
import { Server, Socket } from "socket.io";
import { RoomsService } from "../rooms/rooms.service";
import { InboxService } from "../inbox/inbox.service";
import { MediaService } from "../media/media.service";
import { AuditService } from "../audit/audit.service";
import { MetricsService } from "./metrics.service";
import { CryptoUtils } from "../inbox/crypto-utils.service";
import { Inject, Logger } from "@nestjs/common";
import { ConfigService } from "@nestjs/config";
import Redis from "ioredis";
import { randomBytes } from "crypto";

@WebSocketGateway({
  cors: {
    origin: "*",
  },
})
export class RelayGateway implements OnGatewayConnection, OnGatewayDisconnect {
  private readonly logger = new Logger(RelayGateway.name);

  @WebSocketServer()
  server: Server;

  private readonly RATE_LIMIT_HOUR: number;
  private readonly RATE_LIMIT_DAY: number;

  constructor(
    private readonly roomsService: RoomsService,
    private readonly inboxService: InboxService,
    private readonly mediaService: MediaService,
    private readonly auditService: AuditService,
    private readonly metricsService: MetricsService,
    private readonly cryptoUtils: CryptoUtils,
    private readonly configService: ConfigService,
    @Inject("REDIS_SUBSCRIBER") private readonly redisSub: Redis,
    @Inject("REDIS_CLIENT") private readonly redis: Redis,
  ) {
    this.RATE_LIMIT_HOUR = parseInt(
      this.configService.get<string>("RATE_LIMIT_HOUR") || "50",
    );
    this.RATE_LIMIT_DAY = parseInt(
      this.configService.get<string>("RATE_LIMIT_DAY") || "500",
    );
    this.setupKeyspaceNotifications();
  }

  async handleConnection(client: Socket) {
    this.logger.log(`Client connected: ${client.id}`);

    // Auto-send challenge for V2 identities
    const nonce = randomBytes(32).toString("hex");
    await this.inboxService.storeChallenge(client.id, nonce);
    client.emit("identity.challenge", { nonce });
    await this.auditService.log("client_connected", { socket_id: client.id });
  }

  async handleDisconnect(client: Socket) {
    this.logger.log(`Client disconnected: ${client.id}`);
    await this.inboxService.deleteChallenge(client.id);
    await this.auditService.log("client_disconnected", {
      socket_id: client.id,
      public_id: client.data.publicId,
    });
  }

  @SubscribeMessage("identity.prove")
  async handleIdentityProve(
    client: Socket,
    payload: { public_id: string; public_key: string; signature: string },
  ) {
    const nonce = await this.inboxService.getChallenge(client.id);
    if (!nonce) {
      client.emit("error", { message: "Challenge expired or not found" });
      return;
    }

    const derivedId = this.cryptoUtils.derivePublicId(payload.public_key);
    if (derivedId !== payload.public_id) {
      client.emit("error", { message: "Invalid Public ID for provided key" });
      return;
    }

    const isValid = this.cryptoUtils.verifySignature(
      nonce,
      payload.signature,
      payload.public_key,
    );
    if (!isValid) {
      client.emit("error", { message: "Cryptographic proof failed" });
      return;
    }

    client.data.publicId = payload.public_id;
    await client.join(`inbox:${payload.public_id}`);

    this.logger.log(`Client ${client.id} verified as ${payload.public_id}`);
    await this.auditService.log("identity_verified", {
      public_id: payload.public_id,
      socket_id: client.id,
    });
    client.emit("identity.verified", { public_id: payload.public_id });
    await this.inboxService.deleteChallenge(client.id);
  }

  @SubscribeMessage("inbox.fetch")
  async handleInboxFetch(client: Socket, payload: { since?: number }) {
    const publicId = client.data.publicId;
    if (!publicId) {
      client.emit("error", {
        message: "Unauthenticated. Prove identity first.",
      });
      return;
    }

    const messages = await this.inboxService.fetchMessages(
      publicId,
      payload.since || 0,
    );
    client.emit("inbox.messages", { messages });
    await this.auditService.log("inbox_fetched", {
      public_id: publicId,
      count: messages.length,
    });
    this.metricsService.downloadsTotal.inc();
  }

  @SubscribeMessage("message.ack")
  async handleMessageAck(client: Socket, payload: { message_id: string }) {
    const publicId = client.data.publicId;
    if (!publicId) return;

    await this.inboxService.acknowledgeMessage(publicId, payload.message_id);
    this.logger.log(
      `Message ${payload.message_id} acknowledged by ${publicId}`,
    );
    await this.auditService.log("message_acked", {
      message_id: payload.message_id,
      recipient: publicId,
    });
    this.metricsService.messagesAcked.inc();
  }

  @SubscribeMessage("media.viewed")
  async handleMediaViewed(client: Socket, payload: { media_id: string }) {
    const publicId = client.data.publicId;
    if (!publicId) return;

    await this.mediaService.deleteMedia(payload.media_id);
    this.logger.log(
      `Media ${payload.media_id} deleted after view by ${publicId}`,
    );
    await this.auditService.log("media_viewed", {
      media_id: payload.media_id,
      viewer: publicId,
    });
  }

  @SubscribeMessage("space.join")
  async handleJoin(
    client: Socket,
    payload: { roomId: string; deviceId?: string },
  ) {
    this.logger.log(
      `Join request for room: ${payload.roomId} from client: ${client.id} (Device: ${payload.deviceId || "unknown"})`,
    );
    const room = await this.roomsService.getRoom(payload.roomId);
    if (!room) {
      this.logger.warn(`Room not found: ${payload.roomId}`);
      client.emit("error", { message: "Space not found or expired" });
      return;
    }

    await client.join(payload.roomId);
    client.emit("space.joined", { roomId: payload.roomId });

    const allMessages = await this.roomsService.consumeMessages(payload.roomId);
    const historyToDeliver = allMessages.filter(
      (msg) => msg.senderId !== payload.deviceId,
    );

    if (historyToDeliver.length > 0) {
      client.emit("space.history", {
        roomId: payload.roomId,
        messages: historyToDeliver,
      });
    }
    await this.auditService.log("space_joined", { room_id: payload.roomId });
  }

  @SubscribeMessage("message.send")
  async handleMessage(
    client: Socket,
    payload: {
      target_id: string;
      ciphertext: string;
      nonce?: string;
      expiry?: number;
      senderId?: string;
      v?: number;
      retention?: string;
    },
  ) {
    const payloadSize = Buffer.byteLength(JSON.stringify(payload), "utf8");
    const version = payload.v || 1;
    this.logger.log(
      `GHOST_LOG: MESSAGE_RECEIVED size=${payloadSize} version=${version}`,
    );

    // Size Validation
    const maxSize = version === 2 ? 65536 : 32768; // 64KB for V2, 32KB for V1
    if (payloadSize > maxSize) {
      this.logger.warn(
        `Payload too large from ${client.id} (Size: ${payloadSize})`,
      );
      client.emit("error", { message: "Payload size limit exceeded" });
      await this.auditService.log("payload_rejected", {
        socket_id: client.id,
        size: payloadSize,
      });
      return { status: "error", error: "Payload size limit exceeded" };
    }

    if (version === 2) {
      // V2 Identity-based routing
      const senderPublicId = client.data.publicId;
      if (!senderPublicId) {
        client.emit("error", {
          message: "Unauthenticated. Prove identity first.",
        });
        return {
          status: "error",
          error: "Unauthenticated. Prove identity first.",
        };
      }

      // Rate Limiting (Redis)
      const hourlyKey = `rate:msg:hr:${senderPublicId}`;
      const dailyKey = `rate:msg:day:${senderPublicId}`;

      const [hourlyCount, dailyCount] = await Promise.all([
        this.redis.get(hourlyKey),
        this.redis.get(dailyKey),
      ]);

      if (
        parseInt(hourlyCount || "0") >= this.RATE_LIMIT_HOUR ||
        parseInt(dailyCount || "0") >= this.RATE_LIMIT_DAY
      ) {
        client.emit("error", { message: "Rate limit exceeded" });
        await this.auditService.log("rate_limit_exceeded", {
          public_id: senderPublicId,
        });
        this.metricsService.rateLimitHits.inc();
        return { status: "error", error: "Rate limit exceeded" };
      }

      const pipeline = this.redis.pipeline();
      pipeline.incr(hourlyKey);
      pipeline.expire(hourlyKey, 3600);
      pipeline.incr(dailyKey);
      pipeline.expire(dailyKey, 86400);
      await pipeline.exec();

      this.logger.log(
        `V2 message to ${payload.target_id} from ${senderPublicId}`,
      );
      this.logger.log("GHOST_LOG: MESSAGE_ROUTED");

      try {
        const envelope = await this.inboxService.queueMessage(
          payload.target_id,
          {
            id: (payload as any).id,
            n: (payload as any).n || payload.nonce || "",
            c: (payload as any).c || payload.ciphertext,
            k: (payload as any).k || (payload as any).encryptedKey,
            s: (payload as any).s || (payload as any).signature,
            retention: payload.retention,
          },
          senderPublicId,
        );
        this.logger.log("GHOST_LOG: MESSAGE_STORED");

        this.server
          .to(`inbox:${payload.target_id}`)
          .emit("message.receive", envelope);
        this.logger.log("GHOST_LOG: MESSAGE_DELIVERED");
        await this.auditService.log("message_sent", {
          target: payload.target_id,
          version: 2,
          retention: payload.retention,
        });
        this.metricsService.messagesSent.inc({ version: "2" });
        return { status: "ok", id: envelope.id };
      } catch (e: any) {
        this.logger.error(`Failed to queue V2 message: ${e?.message || e}`);
        return { status: "error", error: e?.message || e };
      }
    } else {
      const roomId = payload.target_id;
      this.logger.log(`V1 message to room ${roomId} from client ${client.id}`);
      this.logger.log("GHOST_LOG: MESSAGE_ROUTED");

      client.to(roomId).emit("message.receive", payload);
      this.logger.log("GHOST_LOG: MESSAGE_DELIVERED");

      try {
        await this.roomsService.addMessage(
          roomId,
          payload,
          payload.expiry || 300,
        );
        this.logger.log("GHOST_LOG: MESSAGE_STORED");
        await this.auditService.log("message_sent", {
          target: roomId,
          version: 1,
        });
        this.metricsService.messagesSent.inc({ version: "1" });
        return { status: "ok" };
      } catch (e: any) {
        this.logger.error(
          `Failed to store V1 message for room ${roomId}: ${e?.message || e}`,
        );
        return { status: "error", error: e?.message || e };
      }
    }
  }

  private setupKeyspaceNotifications() {
    this.redisSub.subscribe("__keyevent@0__:expired");
    this.redisSub.on("message", (channel, message) => {
      if (message.startsWith("room:")) {
        const roomId = message.split(":")[1];
        this.server.to(roomId).emit("space.expired", { roomId });
        this.logger.log(`Space expired: ${roomId}`);
      }
    });
  }
}
