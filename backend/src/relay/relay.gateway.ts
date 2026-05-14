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

    // FETCH AND PURGE (Absolute Ephemeral Policy)
    // We fetch ALL messages, filter for the ones the joiner didn't send,
    // and then DELETE the entire list so it's fresh for the next time.
    const allMessages = await this.roomsService.consumeMessages(payload.roomId);
    
    // Filter out messages sent by this device
    const historyToDeliver = allMessages.filter(msg => msg.senderId !== payload.deviceId);
    
    if (historyToDeliver.length > 0) {
      client.emit("space.history", {
        roomId: payload.roomId,
        messages: historyToDeliver,
      });
      this.logger.log(`Delivered ${historyToDeliver.length} messages to ${client.id} and purged room history.`);
    } else {
      this.logger.log(`Client ${client.id} joined. Room history was already empty or only contained their own messages (now purged).`);
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
