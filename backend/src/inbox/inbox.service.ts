import { Injectable, Inject, Logger } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, MoreThan, IsNull } from 'typeorm';
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
  retention?: string;
}

@Injectable()
export class InboxService {
  private readonly logger = new Logger(InboxService.name);
  private readonly INBOX_TTL = 14 * 24 * 60 * 60; // 14 days for cache
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
    const retentionMode = payload.retention || 'PERSISTENT';
    
    const envelope: MessageEnvelope = {
      id: messageId,
      t: timestamp,
      n: payload.n || payload.nonce,
      c: payload.c || payload.ciphertext,
      k: payload.k || payload.encryptedKey,
      s: payload.s || payload.signature,
      v: payload.v || 2,
      retention: retentionMode,
    };

    let expiresAt: Date | null = null;
    if (retentionMode === 'EPHEMERAL') {
      expiresAt = new Date(timestamp + 30 * 24 * 60 * 60 * 1000); // 30 days
    } else if (retentionMode === 'VIEW_ONCE') {
      expiresAt = new Date(timestamp + 24 * 60 * 60 * 1000); // 24h fallback
    }
    // PERSISTENT mode now has null expiresAt (unlimited)

    try {
      const msgEntity = this.messageRepo.create({
        id: messageId,
        recipient_id: publicId,
        envelope: envelope,
        retention_mode: retentionMode,
        created_at: new Date(timestamp),
        expires_at: expiresAt,
      });
      await this.messageRepo.save(msgEntity);

      const deliveryEntity = this.deliveryRepo.create({
        message_id: messageId,
        recipient_id: publicId,
        status: 'PENDING',
      });
      await this.deliveryRepo.save(deliveryEntity);
      
      this.logger.log(`Audit: Message ${messageId} queued for ${publicId} (Mode: ${retentionMode})`);
    } catch (e: any) {
      this.logger.error(`Failed to save message to Postgres: ${e?.message}`);
      throw e;
    }

    // Cache in Redis
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
    try {
      const messages = await this.messageRepo.find({
        where: [
          {
            recipient_id: publicId,
            delivered_at: IsNull(), // Fetch unread
          },
          {
            recipient_id: publicId,
            created_at: MoreThan(new Date(since)), // Or fetch since timestamp for sync
          }
        ],
        order: {
          created_at: 'ASC',
        },
      });

      if (messages.length > 0) {
        return messages.map(m => m.envelope as MessageEnvelope);
      }
    } catch (e: any) {
      this.logger.error(`Postgres fetch failed: ${e?.message}`);
    }

    return [];
  }

  async acknowledgeMessage(publicId: string, messageId: string): Promise<void> {
    try {
      const message = await this.messageRepo.findOne({ where: { id: messageId } });
      if (!message) return;

      if (message.retention_mode === 'VIEW_ONCE') {
        // Immediate deletion
        await this.messageRepo.delete(messageId);
      } else {
        // Mark as delivered
        message.delivered_at = new Date();
        if (message.retention_mode === 'EPHEMERAL') {
          // Update expiry to 30 days from now if not already set or shorter
          message.expires_at = new Date(Date.now() + 30 * 24 * 60 * 60 * 1000);
        }
        await this.messageRepo.save(message);
      }

      await this.deliveryRepo.update({ message_id: messageId }, { status: 'ACKNOWLEDGED' });
    } catch (e: any) {
      this.logger.error(`Failed to ACK message in Postgres: ${e?.message}`);
    }

    // Remove from Redis cache
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
