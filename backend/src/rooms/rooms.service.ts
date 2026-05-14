import { Injectable, Inject } from '@nestjs/common';
import Redis from 'ioredis';
import { v4 as uuidv4 } from 'uuid';

@Injectable()
export class RoomsService {
  constructor(
    @Inject('REDIS_CLIENT') private readonly redis: Redis,
  ) {}

  async createRoom(config: any): Promise<string> {
    const roomId = uuidv4();
    const expiry = config.expirySeconds || 7200; // Default 2 hours

    const roomKey = `room:${roomId}`;
    const payload = JSON.stringify({
      id: roomId,
      mode: config.mode || 'temporary',
      createdAt: Date.now(),
      expiryAt: Date.now() + (expiry * 1000),
    });

    await this.redis.set(roomKey, payload, 'EX', expiry);
    return roomId;
  }

  async getRoom(roomId: string): Promise<any> {
    const roomKey = `room:${roomId}`;
    const data = await this.redis.get(roomKey);
    return data ? JSON.parse(data) : null;
  }

  async addMessage(roomId: string, message: any, expiry: number): Promise<void> {
    const messageId = uuidv4();
    const messageKey = `msg:${roomId}:${messageId}`;
    
    await this.redis.set(messageKey, JSON.stringify(message), 'EX', expiry);
  }
}
