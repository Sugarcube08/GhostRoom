import { Injectable, Inject } from '@nestjs/common';
import Redis from 'ioredis';
import { v4 as uuidv4 } from 'uuid';

export interface MessageEnvelope {
  id: string;
  t: number; // timestamp
  n: string; // nonce (base64)
  c: string; // ciphertext (base64)
  v: number; // version
}

@Injectable()
export class InboxService {
  constructor(
    @Inject('REDIS_CLIENT') private readonly redis: Redis,
  ) {}

  private readonly INBOX_TTL = 14 * 24 * 60 * 60; // 14 days in seconds
  private readonly MAX_QUEUE_DEPTH = 100;

  async queueMessage(publicId: string, payload: { id?: string; n: string; c: string }): Promise<MessageEnvelope> {
    const messageId = payload.id || uuidv4();
    const timestamp = Date.now();
    
    const envelope: MessageEnvelope = {
      id: messageId,
      t: timestamp,
      n: payload.n,
      c: payload.c,
      v: 2,
    };

    const inboxKey = `inbox:${publicId}`;
    const msgKey = `msg:${messageId}`;

    const pipeline = this.redis.pipeline();
    
    // Store message content
    pipeline.setex(msgKey, this.INBOX_TTL, JSON.stringify(envelope));
    
    // Add to recipient's inbox zset
    pipeline.zadd(inboxKey, timestamp, messageId);
    
    // Enforce queue depth
    pipeline.zremrangebyrank(inboxKey, 0, -(this.MAX_QUEUE_DEPTH + 1));
    
    // Sliding expiry for the inbox set itself
    pipeline.expire(inboxKey, this.INBOX_TTL);

    await pipeline.exec();

    return envelope;
  }

  async fetchMessages(publicId: string, since: number = 0): Promise<MessageEnvelope[]> {
    const inboxKey = `inbox:${publicId}`;
    
    // Fetch message IDs from ZSET
    const messageIds = await this.redis.zrangebyscore(inboxKey, since + 1, '+inf');
    
    if (messageIds.length === 0) return [];

    // Batch fetch message content
    const msgKeys = messageIds.map(id => `msg:${id}`);
    const results = await this.redis.mget(...msgKeys);

    const envelopes: MessageEnvelope[] = [];
    const missingIds: string[] = [];

    results.forEach((data, index) => {
      if (data) {
        envelopes.push(JSON.parse(data));
      } else {
        // Data missing from message store (expired or deleted)
        missingIds.push(messageIds[index]);
      }
    });

    // Cleanup ZSET if we found missing IDs (expired messages)
    if (missingIds.length > 0) {
      await this.redis.zrem(inboxKey, ...missingIds);
    }

    return envelopes;
  }

  async acknowledgeMessage(publicId: string, messageId: string): Promise<void> {
    const inboxKey = `inbox:${publicId}`;
    const msgKey = `msg:${messageId}`;

    const pipeline = this.redis.pipeline();
    pipeline.zrem(inboxKey, messageId);
    pipeline.del(msgKey);
    await pipeline.exec();
  }

  // Authentication Helpers
  async storeChallenge(socketId: string, nonce: string): Promise<void> {
    await this.redis.setex(`challenge:${socketId}`, 60, nonce);
  }

  async getChallenge(socketId: string): Promise<string | null> {
    return await this.redis.get(`challenge:${socketId}`);
  }

  async deleteChallenge(socketId: string): Promise<void> {
    await this.redis.del(`challenge:${socketId}`);
  }
}
