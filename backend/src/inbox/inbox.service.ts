import { Injectable, Inject, Logger } from "@nestjs/common";
import { InjectRepository } from "@nestjs/typeorm";
import { Repository, MoreThan, IsNull, LessThan } from "typeorm";
import { Cron, CronExpression } from "@nestjs/schedule";
import { ConfigService } from "@nestjs/config";
import * as crypto from "crypto";
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

  private oauthToken: string | null = null;
  private oauthTokenExpiresAt = 0;

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
        `Message ${messageId} already exists. Checking delivery status for device: ${recipientDeviceId || "default"}`,
      );
      const existingDelivery = await this.deliveryRepo.findOne({
        where: {
          message_id: messageId,
          recipient_device_id: recipientDeviceId || null,
        },
      });
      if (!existingDelivery) {
        const deliveryEntity = this.deliveryRepo.create({
          message_id: messageId,
          recipient_id: publicId,
          recipient_device_id: recipientDeviceId || null,
          sender_id: senderId,
          status: "PENDING",
        });
        await this.deliveryRepo.save(deliveryEntity);
        this.logger.log(
          `Audit: Additional device delivery queued for ${publicId} device ${recipientDeviceId || "default"}`,
        );
      } else {
        this.logger.log(
          `Idempotent queue: Delivery for message ${messageId} to device ${recipientDeviceId || "default"} already exists.`,
        );
      }
      
      // Still cache in Redis (in case client disconnected and needs fast path)
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
    this.logger.log(`MESSAGE_RECEIVED recipient_identity=${publicId}`);
    this.logger.log(`GHOST_LOG: FCM_RELAY_LOOKUP: START identity_id=${publicId}`);
    const lookupStart = Date.now();
    try {
      const device = await this.deviceRepo.findOne({
        where: { identity_id: publicId },
      });
      const latency = Date.now() - lookupStart;
      if (device) {
        this.logger.log(`GHOST_LOG: FCM_RELAY_LOOKUP: SUCCESS found_token=${!!device.fcm_token} (latency: ${latency}ms)`);
        this.logger.log(`DEVICE_LOOKUP found_token=${!!device.fcm_token} identity_id=${publicId}`);
        if (device.fcm_token) {
          await this.sendFcmWakeup(device.fcm_token);
        }
      } else {
        this.logger.log(`GHOST_LOG: FCM_RELAY_LOOKUP: SUCCESS found_token=false (latency: ${latency}ms)`);
        this.logger.log(`DEVICE_LOOKUP found_token=false identity_id=${publicId}`);
      }
    } catch (fcmErr: any) {
      const latency = Date.now() - lookupStart;
      this.logger.log(`GHOST_LOG: FCM_RELAY_LOOKUP: FAILURE error="${fcmErr.message}" (latency: ${latency}ms)`);
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
      // 1. Find all pending deliveries for this recipient and device
      const deliveries = await this.deliveryRepo.find({
        where: [
          {
            recipient_id: publicId,
            recipient_device_id: deviceId || IsNull(),
            status: "PENDING",
          },
          {
            recipient_id: publicId,
            recipient_device_id: IsNull(),
            status: "PENDING",
          },
        ],
      });

      if (deliveries.length === 0) {
        // Fallback or if there are historical messages since the timestamp:
        const recentMessages = await this.messageRepo.find({
          where: [
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
          order: { created_at: "ASC" },
          take: 500,
        });
        return recentMessages.map((m) => m.envelope as MessageEnvelope);
      }

      // 2. Fetch the actual message envelopes
      const messageIds = deliveries.map((d) => d.message_id);
      const messages = await this.messageRepo.find({
        where: messageIds.map((id) => ({ id })),
        order: { created_at: "ASC" },
      });

      return messages.map((m) => m.envelope as MessageEnvelope);
    } catch (e: any) {
      this.logger.error(`Postgres fetch failed: ${e?.message}`);
      return [];
    }
  }

  async acknowledgeMessage(
    publicId: string,
    messageId: string,
    deviceId?: string,
  ): Promise<{ senderId: string | null } | null> {
    let senderId: string | null = null;
    try {
      // 1. Find and update the specific delivery record for this device
      const delivery = await this.deliveryRepo.findOne({
        where: [
          { message_id: messageId, recipient_id: publicId, recipient_device_id: deviceId || IsNull() },
          { message_id: messageId, recipient_id: publicId, recipient_device_id: IsNull() },
        ],
      });

      if (delivery) {
        senderId = delivery.sender_id;
        delivery.status = "ACKNOWLEDGED";
        await this.deliveryRepo.save(delivery);
        this.logger.log(`Delivery for message ${messageId} to device ${deviceId || "default"} acknowledged.`);
      }

      // 2. Check if all deliveries for this message have been acknowledged
      const allDeliveries = await this.deliveryRepo.find({
        where: { message_id: messageId },
      });
      const allAcked = allDeliveries.every((d) => d.status === "ACKNOWLEDGED");

      if (allAcked) {
        const message = await this.messageRepo.findOne({
          where: { id: messageId },
        });

        if (message) {
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
            // Mark as delivered globally
            if (!message.delivered_at) {
              message.delivered_at = new Date();
              if (message.retention_mode === "EPHEMERAL") {
                message.expires_at = new Date(
                  Date.now() + 30 * 24 * 60 * 60 * 1000,
                );
              }
              await this.messageRepo.save(message);
            }
          }
        }
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

  private async getFcmAccessToken(): Promise<string | null> {
    const serviceAccountJson = this.configService.get<string>("FCM_SERVICE_ACCOUNT");
    if (!serviceAccountJson) {
      return null;
    }

    // Return cached token if valid (leave 30s buffer)
    if (this.oauthToken && this.oauthTokenExpiresAt > Date.now() + 30000) {
      return this.oauthToken;
    }

    try {
      const serviceAccount = JSON.parse(serviceAccountJson);
      const jwtHeader = Buffer.from(JSON.stringify({ alg: "RS256", typ: "JWT" })).toString("base64url");
      const iat = Math.floor(Date.now() / 1000);
      const exp = iat + 3600;
      const jwtPayload = Buffer.from(
        JSON.stringify({
          iss: serviceAccount.client_email,
          scope: "https://www.googleapis.com/auth/firebase.messaging",
          aud: "https://oauth2.googleapis.com/token",
          exp,
          iat,
        }),
      ).toString("base64url");

      const signMaterial = `${jwtHeader}.${jwtPayload}`;
      const signature = crypto
        .sign("SHA256", Buffer.from(signMaterial), serviceAccount.private_key)
        .toString("base64url");
      const jwt = `${jwtHeader}.${jwtPayload}.${signature}`;

      const res = await fetch("https://oauth2.googleapis.com/token", {
        method: "POST",
        headers: { "Content-Type": "application/x-www-form-urlencoded" },
        body: new URLSearchParams({
          grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
          assertion: jwt,
        }),
      });

      if (!res.ok) {
        throw new Error(`Token exchange failed: ${await res.text()}`);
      }

      const data = (await res.json()) as any;
      this.oauthToken = data.access_token;
      this.oauthTokenExpiresAt = Date.now() + data.expires_in * 1000;
      return this.oauthToken;
    } catch (e: any) {
      this.logger.error(`Failed to get OAuth token: ${e.message}`);
      return null;
    }
  }

  async sendFcmWakeup(fcmToken: string): Promise<void> {
    this.logger.log(`GHOST_LOG: FCM_DISPATCH: START token=${fcmToken}`);
    this.logger.log(`FCM_SEND_START token=${fcmToken}`);
    const dispatchStart = Date.now();
    try {
      const oauthToken = await this.getFcmAccessToken();
      const serverKey = this.configService.get<string>("FCM_SERVER_KEY");

      let response: Response;
      let isLegacy = false;

      if (oauthToken) {
        const projectId = this.configService.get<string>("FIREBASE_PROJECT_ID") || "ghostroom-fcm";
        const url = `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`;
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
        response = await fetch(url, {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            Authorization: `Bearer ${oauthToken}`,
          },
          body: JSON.stringify(payload),
        });
      } else if (serverKey) {
        isLegacy = true;
        const url = "https://fcm.googleapis.com/fcm/send";
        const payload = {
          to: fcmToken,
          data: {
            event: "sync_required",
          },
          priority: "high",
        };
        response = await fetch(url, {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            Authorization: `key=${serverKey}`,
          },
          body: JSON.stringify(payload),
        });
      } else {
        throw new Error("No FCM credentials configured (FCM_SERVICE_ACCOUNT or FCM_SERVER_KEY required)");
      }

      const latency = Date.now() - dispatchStart;
      const errText = !response.ok ? await response.text() : "";

      if (!response.ok) {
        this.logger.log(`GHOST_LOG: FCM_DISPATCH: FAILURE error="${errText}" status=${response.status} (latency: ${latency}ms)`);
        this.logger.error(
          `FCM_RESPONSE success=false error="${errText}" status=${response.status}`,
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
        const resJson = (await response.json()) as any;
        const msgId = isLegacy ? (resJson.message_id || "unknown") : (resJson.name || "unknown");
        this.logger.log(`GHOST_LOG: FCM_DISPATCH: SUCCESS message_id=${msgId} (latency: ${latency}ms)`);
        this.logger.log(`FCM_RESPONSE success=true message_id=${msgId}`);
      }
    } catch (err: any) {
      const latency = Date.now() - dispatchStart;
      this.logger.log(`GHOST_LOG: FCM_DISPATCH: FAILURE error="${err.message}" (latency: ${latency}ms)`);
      this.logger.error(`FCM_RESPONSE success=false error="${err.message}"`);
    }
  }
}
