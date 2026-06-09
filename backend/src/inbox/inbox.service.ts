import { Injectable, Inject, Logger } from "@nestjs/common";
import { InjectRepository } from "@nestjs/typeorm";
import { Repository, MoreThan, IsNull, LessThan } from "typeorm";
import { Cron, CronExpression } from "@nestjs/schedule";
import { ConfigService } from "@nestjs/config";
import Redis from "ioredis";
import { v4 as uuidv4 } from "uuid";
import { MessageEntity } from "./entities/message.entity";
import { DeliveryEntity } from "./entities/delivery.entity";
import { DeviceEntity } from "./entities/device.entity";
import { MediaService } from "../media/media.service";

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
    @InjectRepository(DeviceEntity)
    private readonly deviceRepo: Repository<DeviceEntity>,
    private readonly mediaService: MediaService,
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
    recipientDeviceId?: string,
  ): Promise<MessageEnvelope> {
    // Enforcement 1: Global Inbox Cap (Device Specific)
    const pendingCount = await this.deliveryRepo.count({
      where: {
        recipient_id: publicId,
        recipient_device_id: recipientDeviceId || IsNull(),
        status: "PENDING",
      },
    });
    if (pendingCount >= this.INBOX_MAX_MESSAGES) {
      throw new Error("capacity_exceeded: Recipient inbox is full");
    }

    // Enforcement 2: Sender-Recipient Pair Cap
    if (senderId) {
      const pairCount = await this.deliveryRepo.count({
        where: {
          recipient_id: publicId,
          recipient_device_id: recipientDeviceId || IsNull(),
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
    const timestamp = payload.t || Date.now();
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

    const mediaId = payload.media_id || null;

    // Check if message already exists in database first (idempotent path)
    const existingMsg = await this.messageRepo.findOne({
      where: { id: messageId },
    });
    if (existingMsg) {
      this.logger.log(
        `Idempotent queue: Message ${messageId} already exists in database.`,
      );
      return envelope;
    }

    if (mediaId) {
      // Increment reference count first. If this throws (e.g. Media not found / upload not confirmed),
      // the error propagates and we abort queueMessage before saving the message.
      await this.mediaService.incrementReferenceCount(mediaId);
    }

    try {
      const msgEntity = this.messageRepo.create({
        id: messageId,
        recipient_id: publicId,
        recipient_device_id: recipientDeviceId || null,
        envelope: envelope,
        retention_mode: retentionMode,
        created_at: new Date(timestamp),
        expires_at: expiresAt,
        media_id: mediaId,
      });
      await this.messageRepo.save(msgEntity);

      const deliveryEntity = this.deliveryRepo.create({
        message_id: messageId,
        recipient_id: publicId,
        recipient_device_id: recipientDeviceId || null,
        sender_id: senderId,
        status: "PENDING",
      });
      await this.deliveryRepo.save(deliveryEntity);

      this.logger.log(
        `Audit: Message ${messageId} queued for ${publicId} device ${recipientDeviceId || "default"}`,
      );
    } catch (e: any) {
      if (
        e?.code === "23505" ||
        e?.message?.includes("unique constraint") ||
        e?.message?.includes("duplicate key") ||
        e?.message?.includes("UniqueConstraintError")
      ) {
        this.logger.log(
          `Idempotent queue: Message ${messageId} already exists in database.`,
        );
      } else {
        if (mediaId) {
          try {
            await this.mediaService.decrementReferenceCount(mediaId);
          } catch (decErr) {
            this.logger.error(
              `Failed to rollback media reference for ${mediaId}: ${decErr}`,
            );
          }
        }
        this.logger.error(`Failed to save message to Postgres: ${e?.message}`);
        throw e;
      }
    }

    // Cache in Redis (Device Specific)
    const inboxKey = recipientDeviceId
      ? `inbox:${publicId}:${recipientDeviceId}`
      : `inbox:${publicId}`;
    const msgKey = `msg:${messageId}`;

    const pipeline = this.redis.pipeline();
    pipeline.setex(msgKey, this.INBOX_TTL, JSON.stringify(envelope));
    pipeline.zadd(inboxKey, timestamp, messageId);
    pipeline.zremrangebyrank(inboxKey, 0, -(this.INBOX_MAX_MESSAGES + 1));
    pipeline.expire(inboxKey, this.INBOX_TTL);
    await pipeline.exec();

    // Lookup recipient FCM Token and send FCM wake-up
    try {
      const device = await this.deviceRepo.findOne({
        where: { identity_id: publicId },
      });
      if (device && device.fcm_token) {
        await this.sendFcmWakeup(device.fcm_token);
      }
    } catch (fcmErr: any) {
      this.logger.error(
        `Failed to lookup FCM token or send wake-up for recipient ${publicId}: ${fcmErr.message}`,
      );
    }

    return envelope;
  }

  async fetchMessages(
    publicId: string,
    since: number = 0,
    deviceId?: string,
  ): Promise<MessageEnvelope[]> {
    try {
      const messages = await this.messageRepo.find({
        where: [
          {
            recipient_id: publicId,
            recipient_device_id: deviceId || IsNull(),
            delivered_at: IsNull(),
          },
          {
            recipient_id: publicId,
            recipient_device_id: IsNull(),
            delivered_at: IsNull(),
          },
          {
            recipient_id: publicId,
            recipient_device_id: deviceId || IsNull(),
            created_at: MoreThan(new Date(since)),
          },
          {
            recipient_id: publicId,
            recipient_device_id: IsNull(),
            created_at: MoreThan(new Date(since)),
          },
        ],
        order: {
          created_at: "ASC",
        },
        take: 500,
      });

      if (messages.length > 0) {
        return messages.map((m) => m.envelope as MessageEnvelope);
      }
    } catch (e: any) {
      this.logger.error(`Postgres fetch failed: ${e?.message}`);
    }

    return [];
  }

  async acknowledgeMessage(
    publicId: string,
    messageId: string,
    deviceId?: string,
  ): Promise<{ senderId: string | null } | null> {
    let senderId: string | null = null;
    try {
      const delivery = await this.deliveryRepo.findOne({
        where: { message_id: messageId, recipient_id: publicId },
      });
      if (delivery) {
        senderId = delivery.sender_id;
      }

      const message = await this.messageRepo.findOne({
        where: { id: messageId },
      });
      if (!message) return senderId ? { senderId } : null;

      if (message.retention_mode === "VIEW_ONCE") {
        if (message.media_id) {
          try {
            await this.mediaService.decrementReferenceCount(message.media_id);
          } catch (e: any) {
            this.logger.error(
              `Failed to decrement media refcount for VIEW_ONCE message: ${e?.message}`,
            );
          }
        }
        await this.messageRepo.delete(messageId);
        await this.deliveryRepo.delete({ message_id: messageId });
      } else {
        // Mark as delivered
        if (!message.delivered_at) {
          message.delivered_at = new Date();
          if (message.retention_mode === "EPHEMERAL") {
            message.expires_at = new Date(
              Date.now() + 30 * 24 * 60 * 60 * 1000,
            );
          }
          await this.messageRepo.save(message);
        }

        await this.deliveryRepo.update(
          { message_id: messageId },
          { status: "ACKNOWLEDGED" },
        );
      }
    } catch (e: any) {
      this.logger.error(`Failed to ACK message in Postgres: ${e?.message}`);
    }

    // Remove from Redis cache
    const inboxKey = deviceId
      ? `inbox:${publicId}:${deviceId}`
      : `inbox:${publicId}`;
    const msgKey = `msg:${messageId}`;

    const pipeline = this.redis.pipeline();
    pipeline.zrem(inboxKey, messageId);
    pipeline.del(msgKey);
    await pipeline.exec();

    return senderId ? { senderId } : null;
  }

  async markMessageSeen(
    publicId: string,
    messageId: string,
  ): Promise<{ senderId: string | null } | null> {
    try {
      const message = await this.messageRepo.findOne({
        where: { id: messageId, recipient_id: publicId },
      });

      if (!message) return null;

      if (!message.viewed_at) {
        message.viewed_at = new Date();
        await this.messageRepo.save(message);
      }

      const delivery = await this.deliveryRepo.findOne({
        where: { message_id: messageId },
      });

      return { senderId: delivery?.sender_id || null };
    } catch (e: any) {
      this.logger.error(`Failed to mark message as seen: ${e?.message}`);
      return null;
    }
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
      const expiredMessages = await this.messageRepo.find({
        where: { expires_at: LessThan(now) },
      });

      for (const msg of expiredMessages) {
        if (msg.media_id) {
          try {
            await this.mediaService.decrementReferenceCount(msg.media_id);
          } catch (e: any) {
            this.logger.error(
              `Failed to decrement media refcount on expiry: ${e?.message}`,
            );
          }
        }
      }

      if (expiredMessages.length > 0) {
        const ids = expiredMessages.map((m) => m.id);
        const result = await this.messageRepo.delete(ids);
        if (result.affected && result.affected > 0) {
          this.logger.log(`Pruned ${result.affected} expired messages.`);
        }
      }
    } catch (e: any) {
      this.logger.error(`Failed to prune expired messages: ${e?.message}`);
    }
  }

  async deleteMessages(publicId: string, messageIds: string[]): Promise<void> {
    try {
      const messages = await this.messageRepo.find({
        where: messageIds.map((id) => ({ id })),
      });

      for (const msg of messages) {
        const isRecipient = msg.recipient_id === publicId;

        if (isRecipient) {
          if (msg.media_id) {
            try {
              await this.mediaService.decrementReferenceCount(msg.media_id);
            } catch (e: any) {
              this.logger.error(
                `Failed to decrement media refcount on delete: ${e?.message}`,
              );
            }
          }

          await this.messageRepo.delete(msg.id);
          await this.deliveryRepo.delete({ message_id: msg.id });

          // Also remove from Redis cache for recipient
          const pipeline = this.redis.pipeline();
          pipeline.zrem(`inbox:${msg.recipient_id}`, msg.id);
          pipeline.del(`msg:${msg.id}`);
          await pipeline.exec();

          this.logger.log(
            `GHOST_LOG: Message ${msg.id} deleted by recipient ${publicId}`,
          );
        }
      }
    } catch (e: any) {
      this.logger.error(`Failed to delete messages: ${e?.message}`);
    }
  }

  async registerDevice(
    identityId: string,
    platform: string,
    fcmToken: string,
  ): Promise<void> {
    await this.deviceRepo.save({
      identity_id: identityId,
      platform,
      fcm_token: fcmToken,
      updated_at: new Date(),
    });
    this.logger.log(`Device registered: ${identityId} (${platform})`);
  }

  async sendFcmWakeup(fcmToken: string): Promise<void> {
    const projectId =
      this.configService.get<string>("FIREBASE_PROJECT_ID") || "ghostroom-fcm";
    const url = `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`;
    this.logger.log(`Sending FCM Wake-Up to token: ${fcmToken}`);
    try {
      const payload = {
        message: {
          token: fcmToken,
          data: {
            event: "sync_required",
          },
          android: {
            priority: "high" as const,
          },
          apns: {
            headers: {
              "apns-priority": "5",
              "apns-push-type": "background",
            },
            payload: {
              aps: {
                "content-available": 1,
              },
            },
          },
        },
      };

      const response = await fetch(url, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${this.configService.get<string>("FCM_SERVER_KEY") || ""}`,
        },
        body: JSON.stringify(payload),
      });

      if (!response.ok) {
        const errText = await response.text();
        this.logger.warn(
          `FCM delivery failed: status ${response.status}, body ${errText}`,
        );
        if (
          response.status === 404 ||
          response.status === 410 ||
          errText.includes("UNREGISTERED") ||
          errText.includes("InvalidRegistration")
        ) {
          this.logger.log(`Removing stale FCM token from database: ${fcmToken}`);
          await this.deviceRepo.delete({ fcm_token: fcmToken });
        }
      } else {
        this.logger.log(`FCM Wake-Up successfully sent.`);
      }
    } catch (err: any) {
      this.logger.error(`FCM Wake-Up call failed: ${err.message}`);
    }
  }
}
