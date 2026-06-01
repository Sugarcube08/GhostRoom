import { Injectable, Inject } from "@nestjs/common";
import Redis from "ioredis";
import { v4 as uuidv4 } from "uuid";

@Injectable()
export class RoomsService {
  constructor(@Inject("REDIS_CLIENT") private readonly redis: Redis) {}

  async createRoom(config: any): Promise<string> {
    const roomId = uuidv4();
    const expiry = config.expirySeconds || 7200; // Default 2 hours

    const roomKey = `room:${roomId}`;
    const payload = JSON.stringify({
      id: roomId,
      mode: config.mode || "temporary",
      createdAt: Date.now(),
      expiryAt: Date.now() + expiry * 1000,
    });

    await this.redis.set(roomKey, payload, "EX", expiry);
    return roomId;
  }

  async getRoom(roomId: string): Promise<any> {
    const roomKey = `room:${roomId}`;
    const data = await this.redis.get(roomKey);
    return data ? JSON.parse(data) : null;
  }

  async addMessage(
    roomId: string,
    message: any,
    expiry: number,
  ): Promise<void> {
    const listKey = `msgs:${roomId}`;

    const payload = {
      ...message,
      serverTimestamp: Date.now(),
    };

    console.log(
      `[RoomsService] Adding message to room ${roomId}. List TTL: ${expiry}s`,
    );

    // Store message in a list (capped to 50 messages to save memory)
    await this.redis.lpush(listKey, JSON.stringify(payload));
    await this.redis.ltrim(listKey, 0, 49);

    // Ensure the message list expires when the room does
    await this.redis.expire(listKey, expiry);
  }

  async consumeMessages(roomId: string): Promise<any[]> {
    const listKey = `msgs:${roomId}`;

    // Use a transaction to get and delete (Atomicity)
    const pipeline = this.redis.multi();
    pipeline.lrange(listKey, 0, -1);
    pipeline.del(listKey);

    const results = await pipeline.exec();
    if (!results) return [];

    const rangeResult = results[0][1] as string[];
    const data = rangeResult || [];

    if (data.length > 0) {
      console.log(
        `[RoomsService] Consumed ${data.length} messages for room ${roomId}`,
      );
    }

    // Return messages in chronological order (oldest to newest)
    return data.map((m: string) => JSON.parse(m)).reverse();
  }

  async getMessages(roomId: string): Promise<any[]> {
    const listKey = `msgs:${roomId}`;
    const data = await this.redis.lrange(listKey, 0, -1);
    return data.map((m) => JSON.parse(m)).reverse();
  }
}
