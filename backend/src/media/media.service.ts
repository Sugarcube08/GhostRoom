import { Injectable, Inject, Logger } from "@nestjs/common";
import { ConfigService } from "@nestjs/config";
import { InjectRepository } from "@nestjs/typeorm";
import { Repository, LessThan } from "typeorm";
import {
  S3Client,
  PutObjectCommand,
  GetObjectCommand,
  DeleteObjectCommand,
} from "@aws-sdk/client-s3";
import { getSignedUrl } from "@aws-sdk/s3-request-presigner";
import Redis from "ioredis";
import { v4 as uuidv4 } from "uuid";
import { MediaEntity } from "./entities/media.entity";
import { AuditService } from "../audit/audit.service";

@Injectable()
export class MediaService {
  private readonly s3Client: S3Client;
  private readonly bucketName: string;
  private readonly logger = new Logger(MediaService.name);

  private readonly BYTES_LIMIT: number;
  private readonly COUNT_LIMIT: number;

  constructor(
    private readonly configService: ConfigService,
    @Inject("REDIS_CLIENT") private readonly redis: Redis,
    @InjectRepository(MediaEntity)
    private readonly mediaRepo: Repository<MediaEntity>,
    private readonly auditService: AuditService,
  ) {
    const accountId = this.configService.get<string>("R2_ACCOUNT_ID");
    const accessKeyId = this.configService.get<string>("R2_ACCESS_KEY_ID");
    const secretAccessKey = this.configService.get<string>(
      "R2_SECRET_ACCESS_KEY",
    );
    const endpoint = this.configService.get<string>("R2_ENDPOINT");
    this.bucketName =
      this.configService.get<string>("R2_BUCKET_NAME") || "ghostroom-media";

    this.BYTES_LIMIT = parseInt(
      this.configService.get<string>("MEDIA_DAILY_BYTES_LIMIT") || "104857600",
    );
    this.COUNT_LIMIT = parseInt(
      this.configService.get<string>("MEDIA_DAILY_COUNT_LIMIT") || "50",
    );

    this.s3Client = new S3Client({
      region: "auto",
      endpoint: endpoint || `https://${accountId}.r2.cloudflarestorage.com`,
      forcePathStyle: !!endpoint, // Mandatory for MinIO
      credentials: {
        accessKeyId: accessKeyId || "",
        secretAccessKey: secretAccessKey || "",
      },
    });
  }

  async checkQuotas(ownerId: string, size: number) {
    const bytesKey = `quota:bytes:${ownerId}`;
    const countKey = `quota:count:${ownerId}`;

    const [currentBytes, currentCount] = await Promise.all([
      this.redis.get(bytesKey),
      this.redis.get(countKey),
    ]);

    if (parseInt(currentCount || "0") >= this.COUNT_LIMIT) {
      throw new Error("Daily upload count limit reached");
    }

    if (parseInt(currentBytes || "0") + size > this.BYTES_LIMIT) {
      throw new Error("Daily upload size limit reached");
    }
  }

  async generateUploadUrl(
    ownerId: string,
    size: number,
    mime: string,
    hash: string,
    dynamicPublicEndpoint?: string,
  ) {
    await this.checkQuotas(ownerId, size);

    const mediaId = uuidv4();
    const expiresAt = new Date(Date.now() + 48 * 60 * 60 * 1000); // 48 hours

    // 1. Bulk URL
    const bulkCommand = new PutObjectCommand({
      Bucket: this.bucketName,
      Key: `media/${mediaId}`,
      ContentLength: size,
      ContentType: mime,
    });
    const uploadUrl = await getSignedUrl(this.s3Client, bulkCommand, {
      expiresIn: 3600,
    });

    // 2. Thumb URL
    const thumbCommand = new PutObjectCommand({
      Bucket: this.bucketName,
      Key: `thumbs/${mediaId}`,
      ContentType: "image/jpeg",
    });
    const thumbUrl = await getSignedUrl(this.s3Client, thumbCommand, {
      expiresIn: 3600,
    });

    // 3. Store metadata in Postgres
    try {
      const mediaEntity = this.mediaRepo.create({
        id: mediaId,
        owner_id: ownerId,
        size_bytes: size.toString(),
        mime_type: mime,
        content_hash: hash,
        state: "UPLOADING",
        expires_at: expiresAt,
      });
      await this.mediaRepo.save(mediaEntity);
      await this.auditService.log("media_upload_requested", {
        owner: ownerId,
        size,
      });
    } catch (e: any) {
      this.logger.error(
        `Failed to save media metadata to Postgres: ${e?.message}`,
      );
      throw e;
    }

    // Increment Quotas in Redis
    const bytesKey = `quota:bytes:${ownerId}`;
    const countKey = `quota:count:${ownerId}`;

    const pipeline = this.redis.pipeline();
    pipeline.incrby(bytesKey, size);
    pipeline.incr(countKey);
    pipeline.expire(bytesKey, 86400); // 24h
    pipeline.expire(countKey, 86400);
    await pipeline.exec();

    return {
      mediaId,
      uploadUrl: this.mapToPublicUrl(uploadUrl, dynamicPublicEndpoint),
      thumbUrl: this.mapToPublicUrl(thumbUrl, dynamicPublicEndpoint),
    };
  }

  async confirmUpload(ownerId: string, mediaId: string) {
    const metadata = await this.mediaRepo.findOne({ where: { id: mediaId } });

    if (!metadata || metadata.owner_id !== ownerId) {
      throw new Error("Forbidden: Not the media owner");
    }

    metadata.state = "UPLOADED";
    await this.mediaRepo.save(metadata);
    await this.auditService.log("media_upload_confirmed", {
      media_id: mediaId,
      owner: ownerId,
    });
  }

  async referenceMedia(ownerId: string, mediaId: string) {
    const metadata = await this.mediaRepo.findOne({ where: { id: mediaId } });

    if (!metadata || metadata.owner_id !== ownerId) {
      throw new Error("Forbidden: Not the media owner");
    }

    if (metadata.state !== "UPLOADED") {
      throw new Error("Bad Request: Media must be UPLOADED before REFERENCED");
    }

    metadata.state = "REFERENCED";
    await this.mediaRepo.save(metadata);
    await this.auditService.log("media_referenced", {
      media_id: mediaId,
      owner: ownerId,
    });
  }

  async generateDownloadUrl(mediaId: string, dynamicPublicEndpoint?: string) {
    const metadata = await this.mediaRepo.findOne({ where: { id: mediaId } });
    if (
      !metadata ||
      (metadata.expires_at && metadata.expires_at.getTime() < Date.now())
    ) {
      throw new Error("Media not found or expired");
    }

    const command = new GetObjectCommand({
      Bucket: this.bucketName,
      Key: `media/${mediaId}`,
    });

    const downloadUrl = await getSignedUrl(this.s3Client, command, {
      expiresIn: 3600,
    });
    return {
      downloadUrl: this.mapToPublicUrl(downloadUrl, dynamicPublicEndpoint),
      metadata,
    };
  }

  private mapToPublicUrl(url: string, dynamicPublicEndpoint?: string): string {
    const publicEndpoint =
      this.configService.get<string>("R2_PUBLIC_ENDPOINT") ||
      dynamicPublicEndpoint;
    if (!publicEndpoint) return url;

    try {
      const parsedUrl = new URL(url);
      const parsedPublic = new URL(publicEndpoint);
      parsedUrl.protocol = parsedPublic.protocol;
      parsedUrl.host = parsedPublic.host;
      return parsedUrl.toString();
    } catch {
      return url;
    }
  }

  async deleteMedia(mediaId: string) {
    try {
      await this.s3Client.send(
        new DeleteObjectCommand({
          Bucket: this.bucketName,
          Key: `media/${mediaId}`,
        }),
      );
      await this.s3Client.send(
        new DeleteObjectCommand({
          Bucket: this.bucketName,
          Key: `thumbs/${mediaId}`,
        }),
      );
    } catch (e: any) {
      this.logger.error(
        `Failed to delete media ${mediaId} from R2: ${e?.message || e}`,
      );
    }

    await this.mediaRepo.delete(mediaId);
  }

  async cleanup() {
    this.logger.log("Starting media cleanup worker...");
    const now = new Date();

    // 1. Find expired media
    const expiredMedia = await this.mediaRepo.find({
      where: {
        expires_at: LessThan(now),
      },
    });

    for (const media of expiredMedia) {
      this.logger.log(`Pruning expired media: ${media.id}`);
      await this.deleteMedia(media.id);
      await this.auditService.log("media_pruned", {
        media_id: media.id,
        reason: "expired",
      });
    }

    // 2. Find abandoned uploads (UPLOADING for > 2 hours)
    const twoHoursAgo = new Date(now.getTime() - 2 * 60 * 60 * 1000);
    const abandonedMedia = await this.mediaRepo.find({
      where: {
        state: "UPLOADING",
        created_at: LessThan(twoHoursAgo),
      },
    });

    for (const media of abandonedMedia) {
      this.logger.log(`Pruning abandoned upload: ${media.id}`);
      await this.deleteMedia(media.id);
      await this.auditService.log("media_pruned", {
        media_id: media.id,
        reason: "abandoned",
      });
    }
  }
}
