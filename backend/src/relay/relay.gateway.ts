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
  async handleJoin(client: Socket, payload: { roomId: string }) {
    this.logger.log(
      `Join request for room: ${payload.roomId} from client: ${client.id}`,
    );
    const room = await this.roomsService.getRoom(payload.roomId);
    if (!room) {
      this.logger.warn(`Room not found: ${payload.roomId}`);
      client.emit("error", { message: "Space not found or expired" });
      return;
    }

    await client.join(payload.roomId);
    client.emit("space.joined", { roomId: payload.roomId });

    // Fetch and send message history to the late joiner, then clear it (One-time delivery)
    const history = await this.roomsService.consumeMessages(payload.roomId);
    if (history.length > 0) {
      client.emit("space.history", {
        roomId: payload.roomId,
        messages: history,
      });
    }

    this.logger.log(
      `Client ${client.id} successfully joined room ${payload.roomId} and consumed ${history.length} messages`,
    );
  }

  @SubscribeMessage("message.send")
  async handleMessage(
    client: Socket,
    payload: {
      roomId: string;
      ciphertext: string;
      nonce: string;
      expiry: number;
    },
  ) {
    this.logger.log(`Incoming message to room ${payload.roomId} from client ${client.id}`);
    
    // Relay to all other clients in the room
    client.to(payload.roomId).emit("message.receive", payload);

    // Store in Redis with TTL for the NEXT person who joins (if any)
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
