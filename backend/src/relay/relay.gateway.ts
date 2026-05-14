import {
  WebSocketGateway,
  WebSocketServer,
  SubscribeMessage,
  OnGatewayConnection,
  OnGatewayDisconnect,
} from "@nestjs/websockets";
import { Server, Socket } from "socket.io";
import { RoomsService } from "../rooms/rooms.service";
import { Inject, Logger } from "@nestjs/common";
import Redis from "ioredis";

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
    @Inject("REDIS_SUBSCRIBER") private readonly redisSub: Redis,
  ) {
    this.setupKeyspaceNotifications();
  }

  handleConnection(client: Socket) {
    this.logger.log(`Client connected: ${client.id}`);
  }

  handleDisconnect(client: Socket) {
    this.logger.log(`Client disconnected: ${client.id}`);
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

    // Fetch message history
    const allMessages = await this.roomsService.getMessages(payload.roomId);
    
    // Filter history: Only send messages that the joiner DID NOT send
    // and that are 'waiting' for a recipient.
    const historyToDeliver = allMessages.filter(msg => msg.senderId !== payload.deviceId);
    
    if (historyToDeliver.length > 0) {
      client.emit("space.history", {
        roomId: payload.roomId,
        messages: historyToDeliver,
      });

      // GHOST POLICY: Once history is delivered to a recipient, 
      // we can clear those specific messages from the server.
      // For simplicity, we'll clear the whole history if a recipient joins.
      await this.roomsService.consumeMessages(payload.roomId);
      
      this.logger.log(
        `Delivered ${historyToDeliver.length} waiting messages to recipient ${client.id} and cleared history`,
      );
    } else {
      this.logger.log(`Client ${client.id} joined. No new messages for them.`);
    }
  }

  @SubscribeMessage("message.send")
  async handleMessage(
    client: Socket,
    payload: {
      roomId: string;
      ciphertext: string;
      nonce?: string;
      expiry: number;
      senderId?: string;
    },
  ) {
    this.logger.log(`Incoming message to room ${payload.roomId} from client ${client.id} (Sender: ${payload.senderId || 'unknown'})`);
    
    // Relay to all other clients currently in the room
    client.to(payload.roomId).emit("message.receive", payload);

    // Store in Redis ONLY if there are fewer than 2 people in the room 
    // (meaning the recipient might be offline/not joined yet)
    // Or just always store it and let handleJoin consume it.
    try {
      await this.roomsService.addMessage(
        payload.roomId,
        payload,
        payload.expiry || 300,
      );
    } catch (e) {
      this.logger.error(`Failed to store message for room ${payload.roomId}: ${e.message}`);
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
