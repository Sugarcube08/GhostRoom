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
import { CryptoUtils } from "../inbox/crypto-utils.service";
import { Inject, Logger } from "@nestjs/common";
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

  constructor(
    private readonly roomsService: RoomsService,
    private readonly inboxService: InboxService,
    private readonly cryptoUtils: CryptoUtils,
    @Inject("REDIS_SUBSCRIBER") private readonly redisSub: Redis,
  ) {
    this.setupKeyspaceNotifications();
  }

  async handleConnection(client: Socket) {
    this.logger.log(`Client connected: ${client.id}`);
    
    // Auto-send challenge for V2 identities
    const nonce = randomBytes(32).toString('hex');
    await this.inboxService.storeChallenge(client.id, nonce);
    client.emit("identity.challenge", { nonce });
  }

  async handleDisconnect(client: Socket) {
    this.logger.log(`Client disconnected: ${client.id}`);
    await this.inboxService.deleteChallenge(client.id);
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

    // 1. Verify Public ID derivation
    const derivedId = this.cryptoUtils.derivePublicId(payload.public_key);
    if (derivedId !== payload.public_id) {
      client.emit("error", { message: "Invalid Public ID for provided key" });
      return;
    }

    // 2. Verify Signature
    const isValid = this.cryptoUtils.verifySignature(nonce, payload.signature, payload.public_key);
    if (!isValid) {
      client.emit("error", { message: "Cryptographic proof failed" });
      return;
    }

    // 3. Bind Identity
    client.data.publicId = payload.public_id;
    await client.join(`inbox:${payload.public_id}`);
    
    this.logger.log(`Client ${client.id} verified as ${payload.public_id}`);
    client.emit("identity.verified", { public_id: payload.public_id });
    await this.inboxService.deleteChallenge(client.id);
  }

  @SubscribeMessage("inbox.fetch")
  async handleInboxFetch(client: Socket, payload: { since?: number }) {
    const publicId = client.data.publicId;
    if (!publicId) {
      client.emit("error", { message: "Unauthenticated. Prove identity first." });
      return;
    }

    const messages = await this.inboxService.fetchMessages(publicId, payload.since || 0);
    client.emit("inbox.messages", { messages });
  }

  @SubscribeMessage("message.ack")
  async handleMessageAck(client: Socket, payload: { message_id: string }) {
    const publicId = client.data.publicId;
    if (!publicId) return;

    await this.inboxService.acknowledgeMessage(publicId, payload.message_id);
    this.logger.log(`Message ${payload.message_id} acknowledged by ${publicId}`);
  }

  @SubscribeMessage("space.join")
  async handleJoin(client: Socket, payload: { roomId: string; deviceId?: string }) {
    this.logger.log(
      `Join request for room: ${payload.roomId} from client: ${client.id} (Device: ${payload.deviceId || 'unknown'})`,
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
    const historyToDeliver = allMessages.filter(msg => msg.senderId !== payload.deviceId);
    
    if (historyToDeliver.length > 0) {
      client.emit("space.history", {
        roomId: payload.roomId,
        messages: historyToDeliver,
      });
    }
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
    },
  ) {
    const version = payload.v || 1;

    if (version === 2) {
      // V2 Identity-based routing
      this.logger.log(`V2 message to ${payload.target_id} from ${client.id}`);
      
      try {
        const envelope = await this.inboxService.queueMessage(payload.target_id, {
          n: payload.nonce || '',
          c: payload.ciphertext,
        });

        // Live delivery
        this.server.to(`inbox:${payload.target_id}`).emit("message.receive", envelope);
      } catch (e: any) {
        this.logger.error(`Failed to queue V2 message: ${e?.message || e}`);
      }
    } else {
      // V1 Space-based routing
      const roomId = payload.target_id;
      this.logger.log(`V1 message to room ${roomId} from client ${client.id}`);
      
      client.to(roomId).emit("message.receive", payload);

      try {
        await this.roomsService.addMessage(
          roomId,
          payload,
          payload.expiry || 300,
        );
      } catch (e: any) {
        this.logger.error(`Failed to store V1 message for room ${roomId}: ${e?.message || e}`);
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
