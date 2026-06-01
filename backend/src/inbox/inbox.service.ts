import { Injectable, Inject, Logger } from "@nestjs/common";
import { InjectRepository } from "@nestjs/typeorm";
import { Repository, MoreThan, IsNull, LessThan } from "typeorm";
import { Cron, CronExpression } from "@nestjs/schedule";
import { ConfigService } from "@nestjs/config";
import Redis from "ioredis";
import { v4 as uuidv4 } from "uuid";
import { MessageEntity } from "./entities/message.entity";
import { DeliveryEntity } from "./entities/delivery.entity";

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

  private readonly INBOX_MAX_MESSAGES: number;
  private readonly PAIR_PENDING_MAX: number;

  constructor(
    private readonly configService: ConfigService,
    @Inject("REDIS_CLIENT") private readonly redis: Redis,
    @InjectRepository(MessageEntity)
    private readonly messageRepo: Repository<MessageEntity>,
    @InjectRepository(DeliveryEntity)
    private readonly deliveryRepo: Repository<DeliveryEntity>,
  ) {
    this.INBOX_MAX_MESSAGES = parseInt(
      this.configService.get<string>("INBOX_MAX_MESSAGES") || "5000",
    );
    this.PAIR_PENDING_MAX = parseInt(
      this.configService.get<string>("PAIR_PENDING_MAX") || "50",
    );
  }

  async queueMessage(
    publicId: string,
    payload: any,
    senderId?: string,
  ): Promise<MessageEnvelope> {
    // Enforcement 1: Global Inbox Cap
    const pendingCount = await this.deliveryRepo.count({
      where: { recipient_id: publicId, status: "PENDING" },
    });
    if (pendingCount >= this.INBOX_MAX_MESSAGES) {
      throw new Error("capacity_exceeded: Recipient inbox is full");
    }

    // Enforcement 2: Sender-Recipient Pair Cap
    if (senderId) {
      const pairCount = await this.deliveryRepo.count({
        where: {
          recipient_id: publicId,
          sender_id: senderId,
          status: "PENDING",
        },
      });
      if (pairCount >= this.PAIR_PENDING_MAX) {
        throw new Error(
          "capacity_exceeded: Max pending messages for this sender-recipient pair reached",
        );
      }
    }

    const messageId = payload.id || uuidv4();
    const timestamp = Date.now();
    const retentionMode = payload.retention || "PERSISTENT";

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
    if (retentionMode === "EPHEMERAL") {
      expiresAt = new Date(timestamp + 30 * 24 * 60 * 60 * 1000); // 30 days
    } else if (retentionMode === "VIEW_ONCE") {
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
        sender_id: senderId,
        status: "PENDING",
      });
      await this.deliveryRepo.save(deliveryEntity);

      this.logger.log(
        `Audit: Message ${messageId} queued for ${publicId} (Mode: ${retentionMode})`,
      );
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
    pipeline.zremrangebyrank(inboxKey, 0, -(this.INBOX_MAX_MESSAGES + 1));
    pipeline.expire(inboxKey, this.INBOX_TTL);
    await pipeline.exec();

    return envelope;
  }

  async fetchMessages(
    publicId: string,
    since: number = 0,
  ): Promise<MessageEnvelope[]> {
    try {
      const messages = await this.messageRepo.find({
        where: [
          {
            recipient_id: publicId,
            delivered_at: IsNull(),
          },
          {
            recipient_id: publicId,
            created_at: MoreThan(new Date(since)),
          },
        ],
        order: {
          created_at: "ASC",
        },
        take: 500, // Limit to prevent OOM on client
      });

      if (messages.length > 0) {
        return messages.map((m) => m.envelope as MessageEnvelope);
      }
    } catch (e: any) {
      this.logger.error(`Postgres fetch failed: ${e?.message}`);
    }

    return [];
  }

  async acknowledgeMessage(publicId: string, messageId: string): Promise<void> {
    try {
      const message = await this.messageRepo.findOne({
        where: { id: messageId },
      });
      if (!message) return;

      if (message.retention_mode === "VIEW_ONCE") {
        // Immediate deletion
        await this.messageRepo.delete(messageId);
      } else {
        // Mark as delivered
        message.delivered_at = new Date();
        if (message.retention_mode === "EPHEMERAL") {
          // Update expiry to 30 days from now if not already set or shorter
          message.expires_at = new Date(Date.now() + 30 * 24 * 60 * 60 * 1000);
        }
        await this.messageRepo.save(message);
      }

      await this.deliveryRepo.update(
        { message_id: messageId },
        { status: "ACKNOWLEDGED" },
      );
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

  @Cron(CronExpression.EVERY_HOUR)
  async cleanupExpiredMessages(): Promise<void> {
    const now = new Date();
    try {
      const result = await this.messageRepo.delete({
        expires_at: LessThan(now),
      });
      if (result.affected && result.affected > 0) {
        this.logger.log(`Pruned ${result.affected} expired messages.`);
      }
    } catch (e: any) {
      this.logger.error(`Failed to prune expired messages: ${e?.message}`);
    }
  }
}
