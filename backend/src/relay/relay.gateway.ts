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
import { FederationService } from "../federation/federation.service";
import { GroupsService } from "../groups/groups.service";
import { Inject, Logger, OnModuleInit } from "@nestjs/common";
import { ConfigService } from "@nestjs/config";
import Redis from "ioredis";
import { randomBytes } from "crypto";
import { v4 as uuidv4 } from "uuid";
import { io, Socket as ClientSocket } from "socket.io-client";

@WebSocketGateway({
  cors: {
    origin: "*",
  },
})
export class RelayGateway implements OnGatewayConnection, OnGatewayDisconnect, OnModuleInit {
  private readonly logger = new Logger(RelayGateway.name);

  @WebSocketServer()
  server: Server;

  private readonly RATE_LIMIT_HOUR: number;
  private readonly RATE_LIMIT_DAY: number;
  private readonly remoteRelays = new Map<string, ClientSocket>();

  constructor(
    private readonly roomsService: RoomsService,
    private readonly inboxService: InboxService,
    private readonly mediaService: MediaService,
    private readonly auditService: AuditService,
    private readonly metricsService: MetricsService,
    private readonly cryptoUtils: CryptoUtils,
    private readonly configService: ConfigService,
    private readonly federationService: FederationService,
    private readonly groupsService: GroupsService,
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

  onModuleInit() {
    this.inboxService.registerFcmDeliveryCallback(async (senderId, messageId, recipientId) => {
      await this.emitStatusUpdate(senderId, messageId, "DELIVERED", recipientId);
      this.logger.log(`STATUS_UPDATE_EMIT message_id=${messageId} sender_id=${senderId} status=DELIVERED`);
    });
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
    payload: {
      public_id: string;
      public_key: string;
      signature: string;
      device_id?: string;
    },
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
    client.data.deviceId = payload.device_id;

    // Join both primary and device-specific inbox
    this.logger.log(`JOIN_ROOM_START room=inbox:${payload.public_id} socket=${client.id}`);
    await client.join(`inbox:${payload.public_id}`);
    this.logger.log(`JOIN_ROOM_SUCCESS room=inbox:${payload.public_id} socket=${client.id}`);
    
    if (payload.device_id) {
      this.logger.log(`JOIN_ROOM_START room=inbox:${payload.public_id}:${payload.device_id} socket=${client.id}`);
      await client.join(`inbox:${payload.public_id}:${payload.device_id}`);
      this.logger.log(`JOIN_ROOM_SUCCESS room=inbox:${payload.public_id}:${payload.device_id} socket=${client.id}`);
    }

    // Register home relay if RELAY_URL is configured
    const myRelayUrl = this.configService.get<string>("RELAY_URL");
    if (myRelayUrl) {
      await this.federationService.registerHomeRelay(
        payload.public_id,
        myRelayUrl,
        payload.device_id || "default",
      );
    }

    this.logger.log(
      `Client ${client.id} verified as ${payload.public_id} (${payload.device_id || "no-device-id"})`,
    );
    await this.auditService.log("identity_verified", {
      public_id: payload.public_id,
      device_id: payload.device_id,
      socket_id: client.id,
    });
    client.emit("identity.verified", {
      public_id: payload.public_id,
      device_id: payload.device_id,
    });
    await this.inboxService.deleteChallenge(client.id);
  }

  @SubscribeMessage("group.create")
  async handleGroupCreate(client: Socket, payload: { members: string[] }) {
    const creatorId = client.data.publicId;
    if (!creatorId) return { status: "error", error: "Unauthenticated" };

    const groupId = await this.groupsService.createGroup(
      creatorId,
      payload.members,
    );
    return { status: "ok", groupId };
  }

  @SubscribeMessage("group.send")
  async handleGroupMessage(
    client: Socket,
    payload: {
      group_id: string;
      ciphertext: string;
      nonce: string;
      v: number;
    },
  ) {
    const senderId = client.data.publicId;
    if (!senderId) return { status: "error", error: "Unauthenticated" };

    const members = await this.groupsService.getMembers(payload.group_id);
    if (!members.includes(senderId)) {
      return { status: "error", error: "Not a group member" };
    }

    this.logger.log(
      `Group message to ${payload.group_id} from ${senderId}. Fanning out to ${members.length} members.`,
    );

    for (const memberId of members) {
      if (memberId === senderId) continue;

      try {
        // Find member's devices for fan-out
        const devices = await this.federationService.getActiveDevices(memberId);

        for (const deviceId of devices.length > 0 ? devices : [undefined]) {
          const envelope = await this.inboxService.queueMessage(
            memberId,
            {
              id: uuidv4(),
              t: Date.now(),
              v: payload.v || 2,
              n: payload.nonce,
              c: payload.ciphertext,
              retention: "PERSISTENT",
              group_id: payload.group_id,
            },
            senderId,
            deviceId as string,
          );

          const targetRoom = deviceId
            ? `inbox:${memberId}:${deviceId}`
            : `inbox:${memberId}`;

          this.server.to(targetRoom).emit("message.receive", {
            ...envelope,
            group_id: payload.group_id,
          });
        }
      } catch (e: any) {
        this.logger.error(
          `Failed to deliver group message to ${memberId}: ${e.message}`,
        );
      }
    }

    return { status: "ok" };
  }

  @SubscribeMessage("identity.devices")
  async handleGetDevices(client: Socket, payload: { public_id: string }) {
    const devices = await this.federationService.getActiveDevices(
      payload.public_id,
    );
    const deviceDetails = await Promise.all(
      devices.map(async (d) => ({
        device_id: d,
        relay_url: await this.federationService.getDeviceRelay(
          payload.public_id,
          d,
        ),
      })),
    );
    return { status: "ok", devices: deviceDetails };
  }

  @SubscribeMessage("inbox.fetch")
  async handleInboxFetch(client: Socket, payload: { since?: number }) {
    const publicId = client.data.publicId;
    const deviceId = client.data.deviceId;
    if (!publicId) {
      client.emit("error", {
        message: "Unauthenticated. Prove identity first.",
      });
      return;
    }

    const messages = await this.inboxService.fetchMessages(
      publicId,
      payload.since || 0,
      deviceId,
    );
    client.emit("inbox.messages", { messages });
    await this.auditService.log("inbox_fetched", {
      public_id: publicId,
      device_id: deviceId,
      count: messages.length,
    });
    this.metricsService.downloadsTotal.inc();
  }

  @SubscribeMessage("message.ack")
  async handleMessageAck(client: Socket, payload: { message_id: string }) {
    const publicId = client.data.publicId;
    const deviceId = client.data.deviceId;
    if (!publicId) return { success: false, error: "Not authenticated" };

    this.logger.log(`DELIVERY_RECEIPT_RECEIVED message_id=${payload.message_id} recipient_id=${publicId}`);

    const result = await this.inboxService.acknowledgeMessage(
      publicId,
      payload.message_id,
      deviceId,
    );

    if (result && result.senderId) {
      await this.emitStatusUpdate(result.senderId, payload.message_id, "DELIVERED", publicId);
      this.logger.log(`MESSAGE_MARKED_DELIVERED message_id=${payload.message_id} sender_id=${result.senderId} recipient_id=${publicId}`);
    }

    this.logger.log(
      `Message ${payload.message_id} acknowledged by ${publicId} (${deviceId || "default"})`,
    );
    await this.auditService.log("message_acked", {
      message_id: payload.message_id,
      recipient: publicId,
      device_id: deviceId,
    });
    this.metricsService.messagesAcked.inc();
    return { success: true, message_id: payload.message_id };
  }

  @SubscribeMessage("message.seen")
  async handleMessageSeen(client: Socket, payload: { message_id: string }) {
    const publicId = client.data.publicId;
    if (!publicId) return;

    const result = await this.inboxService.markMessageSeen(
      publicId,
      payload.message_id,
    );

    if (result && result.senderId) {
      await this.emitStatusUpdate(result.senderId, payload.message_id, "SEEN", publicId);
    }

    this.logger.log(`Message ${payload.message_id} seen by ${publicId}`);
  }

  @SubscribeMessage("message.delete")
  async handleMessageDelete(
    client: Socket,
    payload: { message_ids: string[] },
  ) {
    const publicId = client.data.publicId;
    if (!publicId) return;

    this.logger.log(
      `GHOST_LOG: Received message.delete event from ${publicId} for: ${payload.message_ids}`,
    );
    await this.inboxService.deleteMessages(publicId, payload.message_ids);
    return { status: "success" };
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
      target_device_id?: string;
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
        // Federation Check: Is recipient local?
        const targetDeviceId = payload.target_device_id;
        let homeRelayUrl: string | null = null;

        if (targetDeviceId) {
          homeRelayUrl = await this.federationService.getDeviceRelay(
            payload.target_id,
            targetDeviceId,
          );
        } else {
          homeRelayUrl = await this.federationService.getHomeRelay(
            payload.target_id,
          );
        }

        const myRelayUrl = this.configService.get<string>("RELAY_URL");
        const isRemote = homeRelayUrl && homeRelayUrl !== myRelayUrl;

        if (isRemote) {
          this.logger.log(
            `Forwarding message to remote relay: ${homeRelayUrl}`,
          );
          await this.forwardToRemote(homeRelayUrl, payload);
          await this.auditService.log("message_forwarded", {
            target: payload.target_id,
            device_id: targetDeviceId,
            relay: homeRelayUrl,
          });
          return { status: "ok", relayed: true };
        }

        const envelope = await this.inboxService.queueMessage(
          payload.target_id,
          {
            id: (payload as any).id,
            t: (payload as any).t,
            v: (payload as any).v || payload.v,
            n: (payload as any).n || payload.nonce || "",
            c: (payload as any).c || payload.ciphertext,
            k: (payload as any).k || (payload as any).encryptedKey,
            s: (payload as any).s || (payload as any).signature,
            retention: payload.retention,
            media_id: (payload as any).media_id,
          },
          senderPublicId,
          targetDeviceId,
        );
        this.logger.log("GHOST_LOG: MESSAGE_STORED");

        const targetRoom = targetDeviceId
          ? `inbox:${payload.target_id}:${targetDeviceId}`
          : `inbox:${payload.target_id}`;

        this.server.to(targetRoom).emit("message.receive", envelope);
        this.logger.log("GHOST_LOG: MESSAGE_DELIVERED");
        await this.auditService.log("message_sent", {
          target: payload.target_id,
          device_id: targetDeviceId,
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

  // --- Federation S2S ---

  @SubscribeMessage("federation.deliver")
  async handleFederationDeliver(
    client: Socket,
    payload: {
      relay_id: string;
      public_key: string;
      signature: string;
      envelope: any;
      recipient: string;
      recipient_device_id?: string;
    },
  ) {
    // 1. Verify Relay Signature
    const isValid = this.federationService.verifyFederationSignature(
      {
        envelope: payload.envelope,
        recipient: payload.recipient,
        recipient_device_id: payload.recipient_device_id,
      },
      payload.signature,
      payload.public_key,
    );

    if (!isValid) {
      this.logger.warn(
        `Invalid federation signature from relay ${payload.relay_id}`,
      );
      return { status: "error", error: "Invalid signature" };
    }

    // 2. Queue locally
    try {
      const envelope = await this.inboxService.queueMessage(
        payload.recipient,
        payload.envelope,
        // In federation, original sender is hidden behind relay ID
        `fed:${payload.relay_id}`,
        payload.recipient_device_id,
      );

      const targetRoom = payload.recipient_device_id
        ? `inbox:${payload.recipient}:${payload.recipient_device_id}`
        : `inbox:${payload.recipient}`;

      this.server.to(targetRoom).emit("message.receive", envelope);
      return { status: "ok" };
    } catch (e: any) {
      return { status: "error", error: e?.message };
    }
  }

  private async forwardToRemote(relayUrl: string, envelope: any) {
    let client = this.remoteRelays.get(relayUrl);

    if (!client || !client.connected) {
      this.logger.log(`Establishing S2S connection to: ${relayUrl}`);
      client = io(relayUrl, {
        reconnection: true,
        transports: ["websocket"],
      });
      this.remoteRelays.set(relayUrl, client);

      await new Promise((resolve, reject) => {
        client!.once("connect", () => resolve(true));
        client!.once("connect_error", reject);
        setTimeout(() => reject(new Error("Relay connection timeout")), 5000);
      });
    }

    const payload = {
      envelope,
      recipient: envelope.target_id,
      recipient_device_id: envelope.target_device_id,
    };

    const signature = this.federationService.signFederationRequest(payload);

    return new Promise((resolve, reject) => {
      client!.emit(
        "federation.deliver",
        {
          relay_id: this.federationService.getRelayPublicId(),
          public_key: this.federationService.getPublicKey(),
          signature,
          ...payload,
        },
        (response: any) => {
          if (response?.status === "ok") resolve(response);
          else
            reject(
              new Error(response?.error || "Remote relay delivery failed"),
            );
        },
      );
    });
  }

  async acknowledgeAndEmitStatus(publicId: string, messageId: string, deviceId?: string) {
    this.logger.log(`DELIVERY_RECEIPT_RECEIVED message_id=${messageId} recipient_id=${publicId}`);
    const result = await this.inboxService.acknowledgeMessage(
      publicId,
      messageId,
      deviceId,
    );
    if (result && result.senderId) {
      await this.emitStatusUpdate(result.senderId, messageId, "DELIVERED", publicId);
      this.logger.log(`MESSAGE_MARKED_DELIVERED message_id=${messageId} sender_id=${result.senderId} recipient_id=${publicId}`);
    }
    return result;
  }

  private async emitStatusUpdate(senderId: string, messageId: string, status: "DELIVERED" | "SEEN", recipientId: string) {
    const room = `inbox:${senderId}`;
    const payload = {
      message_id: messageId,
      status,
      recipient_id: recipientId,
      timestamp: Date.now(),
    };

    this.logger.log(`STATUS_UPDATE_EMIT message_id=${messageId} sender_id=${senderId} status=${status}`);
    this.logger.log(`STATUS_UPDATE_EMIT_START room=${room} message_id=${messageId}`);
    
    const clients = this.server.sockets.adapter.rooms.get(room)?.size ?? 0;
    this.logger.log(`STATUS_UPDATE_ROOM_SIZE room=${room} clients=${clients}`);
    this.logger.log(`STATUS_UPDATE_EMIT_PAYLOAD payload=${JSON.stringify(payload)}`);

    this.server.to(room).emit("message.status_update", payload);

    this.logger.log(`STATUS_UPDATE_EMIT_DONE room=${room} message_id=${messageId}`);
  }
}
