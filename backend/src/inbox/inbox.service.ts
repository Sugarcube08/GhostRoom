import { Injectable, Inject, Logger } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, MoreThan } from 'typeorm';
import Redis from 'ioredis';
import { v4 as uuidv4 } from 'uuid';
import { MessageEntity } from './entities/message.entity';
import { DeliveryEntity } from './entities/delivery.entity';

export interface MessageEnvelope {
  id: string;
  t: number; // timestamp
  n?: string; // nonce (base64)
  c?: string; // ciphertext (base64)
  k?: string; // key (base64)
  s?: string; // signature (base64)
  v: number; // version
}

@Injectable()
export class InboxService {
  private readonly logger = new Logger(InboxService.name);
  private readonly INBOX_TTL = 14 * 24 * 60 * 60; // 14 days in seconds for cache
  private readonly MAX_QUEUE_DEPTH = 100;

  constructor(
    @Inject('REDIS_CLIENT') private readonly redis: Redis,
    @InjectRepository(MessageEntity)
    private readonly messageRepo: Repository<MessageEntity>,
    @InjectRepository(DeliveryEntity)
    private readonly deliveryRepo: Repository<DeliveryEntity>,
  ) {}

  async queueMessage(publicId: string, payload: any): Promise<MessageEnvelope> {
    const messageId = payload.id || uuidv4();
    const timestamp = Date.now();
    
    const envelope: MessageEnvelope = {
      id: messageId,
      t: timestamp,
      n: payload.n || payload.nonce,
      c: payload.c || payload.ciphertext,
      k: payload.k || payload.encryptedKey,
      s: payload.s || payload.signature,
      v: payload.v || 2,
    };

    // 1. Save to PostgreSQL (Durable Source of Truth)
    try {
      const msgEntity = this.messageRepo.create({
        id: messageId,
        recipient_id: publicId,
        envelope: envelope,
        created_at: new Date(timestamp),
      });
      await this.messageRepo.save(msgEntity);

      const deliveryEntity = this.deliveryRepo.create({
        message_id: messageId,
        recipient_id: publicId,
        status: 'PENDING',
      });
      await this.deliveryRepo.save(deliveryEntity);
    } catch (e: any) {
      this.logger.error(`Failed to save message to Postgres: ${e?.message}`);
      throw e;
    }

    // 2. Cache in Redis (Ephemeral)
    const inboxKey = `inbox:${publicId}`;
    const msgKey = `msg:${messageId}`;

    const pipeline = this.redis.pipeline();
    pipeline.setex(msgKey, this.INBOX_TTL, JSON.stringify(envelope));
    pipeline.zadd(inboxKey, timestamp, messageId);
    pipeline.zremrangebyrank(inboxKey, 0, -(this.MAX_QUEUE_DEPTH + 1));
    pipeline.expire(inboxKey, this.INBOX_TTL);
    await pipeline.exec();

    return envelope;
  }

  async fetchMessages(publicId: string, since: number = 0): Promise<MessageEnvelope[]> {
    // Attempt to fetch from Postgres as the reliable source of truth
    try {
      const messages = await this.messageRepo.find({
        where: {
          recipient_id: publicId,
          created_at: MoreThan(new Date(since)),
        },
        order: {
          created_at: 'ASC',
        },
      });

      if (messages.length > 0) {
        return messages.map(m => m.envelope as MessageEnvelope);
      }
    } catch (e: any) {
      this.logger.error(`Postgres fetch failed, falling back to Redis: ${e?.message}`);
    }

    // Fallback to Redis cache if Postgres fails or returns empty but we suspect Redis has it
    // Actually, if Postgres is empty, Redis should be empty too. But let's keep Redis fetch as a fallback.
    const inboxKey = `inbox:${publicId}`;
    const messageIds = await this.redis.zrangebyscore(inboxKey, since + 1, '+inf');
    if (messageIds.length === 0) return [];

    const msgKeys = messageIds.map(id => `msg:${id}`);
    const results = await this.redis.mget(...msgKeys);

    const envelopes: MessageEnvelope[] = [];
    const missingIds: string[] = [];

    results.forEach((data, index) => {
      if (data) {
        envelopes.push(JSON.parse(data));
      } else {
        missingIds.push(messageIds[index]);
      }
    });

    if (missingIds.length > 0) {
      await this.redis.zrem(inboxKey, ...missingIds);
    }

    return envelopes;
  }

  async acknowledgeMessage(publicId: string, messageId: string): Promise<void> {
    // 1. Remove from Postgres
    try {
      await this.messageRepo.delete({ id: messageId, recipient_id: publicId });
      await this.deliveryRepo.update({ message_id: messageId }, { status: 'ACKNOWLEDGED' });
    } catch (e: any) {
      this.logger.error(`Failed to delete message from Postgres: ${e?.message}`);
    }

    // 2. Remove from Redis
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
