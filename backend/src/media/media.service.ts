import { Injectable, Inject, Logger } from "@nestjs/common";
import { ConfigService } from "@nestjs/config";
import { InjectRepository } from "@nestjs/typeorm";
import { Repository, LessThan } from "typeorm";
import {
  S3Client,
  PutObjectCommand,
  GetObjectCommand,
  DeleteObjectCommand,
  HeadObjectCommand,
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
    const publicEndpoint = this.configService.get<string>("R2_PUBLIC_ENDPOINT");
    this.bucketName =
      this.configService.get<string>("R2_BUCKET_NAME") || "ghostroom-media";

    const clientEndpoint =
      endpoint ||
      (accountId ? `https://${accountId}.r2.cloudflarestorage.com` : "") ||
      (publicEndpoint &&
        !publicEndpoint.includes("localhost") &&
        !publicEndpoint.includes("127.0.0.1")
        ? publicEndpoint
        : "");
    const redactedAccessKey = accessKeyId
      ? accessKeyId.length > 6
        ? `${accessKeyId.substring(0, 6)}...`
        : "***"
      : "undefined";

    this.logger.log(`GHOST_LOG: R2_ENDPOINT=${clientEndpoint}`);
    this.logger.log(`GHOST_LOG: R2_BUCKET=${this.bucketName}`);
    this.logger.log(`GHOST_LOG: R2_ACCESS_KEY=${redactedAccessKey}`);

    if (
      this.configService.get<string>("NODE_ENV") === "production" &&
      clientEndpoint.includes("localhost")
    ) {
      throw new Error("Invalid storage endpoint: localhost");
    }

    this.BYTES_LIMIT = parseInt(
      this.configService.get<string>("MEDIA_DAILY_BYTES_LIMIT") || "104857600",
    );
    this.COUNT_LIMIT = parseInt(
      this.configService.get<string>("MEDIA_DAILY_COUNT_LIMIT") || "50",
    );

    const isS3Compatible =
      !!clientEndpoint &&
      (!!endpoint ||
        !!accountId ||
        clientEndpoint.includes("r2.cloudflarestorage.com") ||
        clientEndpoint.includes("minio"));

    this.s3Client = new S3Client({
      region: "auto",
      endpoint: clientEndpoint || undefined,
      forcePathStyle: isS3Compatible,
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
    this.logger.log(
      `GHOST_LOG: MEDIA_CREATE_REQUEST ownerId=${ownerId} size=${size} mime=${mime} hash=${hash}`,
    );
    await this.checkQuotas(ownerId, size);

    const mediaId = uuidv4();
    const expiresAt = new Date(Date.now() + 48 * 60 * 60 * 1000); // 48 hours

    const bulkKey = `media/${mediaId}`;
    const thumbKey = `thumbs/${mediaId}`;

    this.logger.log(
      `GHOST_LOG: UPLOAD_URL REQUEST: ownerId=${ownerId} mediaId=${mediaId} bucket=${this.bucketName} key=${bulkKey} size=${size} mime=${mime} hash=${hash}`,
    );

    this.logger.log(
      `GHOST_LOG: MEDIA_PRESIGN_REQUEST mediaId=${mediaId} bucket=${this.bucketName} key=${bulkKey}`,
    );

    const s3SigningClient = this.getS3ClientForSigning(dynamicPublicEndpoint);

    // 1. Bulk URL
    const bulkCommand = new PutObjectCommand({
      Bucket: this.bucketName,
      Key: bulkKey,
      ContentLength: size,
      ContentType: mime,
    });
    const uploadUrl = await getSignedUrl(s3SigningClient, bulkCommand, {
      expiresIn: 3600,
    });

    // 2. Thumb URL
    const thumbCommand = new PutObjectCommand({
      Bucket: this.bucketName,
      Key: thumbKey,
      ContentType: "image/jpeg",
    });
    const thumbUrl = await getSignedUrl(s3SigningClient, thumbCommand, {
      expiresIn: 3600,
    });

    const mappedUploadUrl = this.mapToPublicUrl(
      uploadUrl,
      dynamicPublicEndpoint,
    );
    const mappedThumbUrl = this.mapToPublicUrl(thumbUrl, dynamicPublicEndpoint);

    this.logger.log(
      `GHOST_LOG: MEDIA_PRESIGN_SUCCESS mediaId=${mediaId} bucket=${this.bucketName} key=${bulkKey}`,
    );
    this.logger.log(
      `GHOST_LOG: UPLOAD_URLS GENERATED: mediaId=${mediaId} uploadUrl=${mappedUploadUrl} thumbUrl=${mappedThumbUrl}`,
    );

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
      uploadUrl: mappedUploadUrl,
      thumbUrl: mappedThumbUrl,
    };
  }

  async confirmUpload(ownerId: string, mediaId: string) {
    const metadata = await this.mediaRepo.findOne({ where: { id: mediaId } });

    if (!metadata || metadata.owner_id !== ownerId) {
      throw new Error("Forbidden: Not the media owner");
    }

    // Verify actual object presence in R2 bucket (P1 Media Integrity)
    try {
      await this.s3Client.send(
        new HeadObjectCommand({
          Bucket: this.bucketName,
          Key: `media/${mediaId}`,
        }),
      );
    } catch (err: any) {
      this.logger.error(
        `Failed to confirm media upload for ${mediaId}: file not found in storage. Error: ${err?.message}`,
      );
      throw new Error(
        `Bad Request: Media file has not been uploaded to storage yet`,
      );
    }

    metadata.state = metadata.reference_count > 0 ? "REFERENCED" : "UPLOADED";
    await this.mediaRepo.save(metadata);
    this.logger.log(
      `GHOST_LOG: R2_UPLOAD_CONFIRMED mediaId=${mediaId} ownerId=${ownerId}`,
    );
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
    this.logger.log(
      `GHOST_LOG: MEDIA_REFERENCE_CREATED mediaId=${mediaId} ownerId=${ownerId}`,
    );
    await this.auditService.log("media_referenced", {
      media_id: mediaId,
      owner: ownerId,
    });
  }

  async generateDownloadUrl(
    mediaId: string,
    dynamicPublicEndpoint?: string,
    isThumbnail = false,
  ) {
    const metadata = await this.mediaRepo.findOne({ where: { id: mediaId } });
    if (
      !metadata ||
      (metadata.expires_at && metadata.expires_at.getTime() < Date.now())
    ) {
      throw new Error("Media not found or expired");
    }

    const key = isThumbnail ? `thumbs/${mediaId}` : `media/${mediaId}`;
    this.logger.log(
      `GHOST_LOG: DOWNLOAD_URL REQUEST: mediaId=${mediaId} bucket=${this.bucketName} key=${key} isThumbnail=${isThumbnail}`,
    );

    const s3SigningClient = this.getS3ClientForSigning(dynamicPublicEndpoint);

    const command = new GetObjectCommand({
      Bucket: this.bucketName,
      Key: key,
    });

    const downloadUrl = await getSignedUrl(s3SigningClient, command, {
      expiresIn: 3600,
    });

    const publicUrl = this.mapToPublicUrl(downloadUrl, dynamicPublicEndpoint);
    this.logger.log(
      `GHOST_LOG: DOWNLOAD_URL GENERATED: mediaId=${mediaId} downloadUrl=${publicUrl}`,
    );

    return {
      downloadUrl: publicUrl,
      metadata,
    };
  }

  private mapToPublicUrl(url: string, dynamicPublicEndpoint?: string): string {
    let publicEndpoint = this.configService.get<string>("R2_PUBLIC_ENDPOINT");
    if (
      !publicEndpoint ||
      publicEndpoint.includes("localhost") ||
      publicEndpoint.includes("127.0.0.1")
    ) {
      if (dynamicPublicEndpoint) {
        publicEndpoint = dynamicPublicEndpoint;
      }
    }
    if (!publicEndpoint) return url;
    if (
      publicEndpoint.includes("r2.cloudflarestorage.com") &&
      url.includes("r2.cloudflarestorage.com")
    ) {
      return url;
    }

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

  private getS3ClientForSigning(dynamicPublicEndpoint?: string): S3Client {
    let publicEndpoint = this.configService.get<string>("R2_PUBLIC_ENDPOINT");
    if (
      !publicEndpoint ||
      publicEndpoint.includes("localhost") ||
      publicEndpoint.includes("127.0.0.1")
    ) {
      if (dynamicPublicEndpoint) {
        publicEndpoint = dynamicPublicEndpoint;
      }
    }

    if (
      publicEndpoint &&
      !publicEndpoint.includes("r2.cloudflarestorage.com")
    ) {
      const accessKeyId = this.configService.get<string>("R2_ACCESS_KEY_ID");
      const secretAccessKey = this.configService.get<string>(
        "R2_SECRET_ACCESS_KEY",
      );
      const endpoint = this.configService.get<string>("R2_ENDPOINT");
      const accountId = this.configService.get<string>("R2_ACCOUNT_ID");
      const isS3Compatible =
        !!endpoint ||
        !!accountId ||
        publicEndpoint.includes("minio") ||
        publicEndpoint.includes("localhost") ||
        publicEndpoint.includes("127.0.0.1");

      // If we are using a custom endpoint (like MinIO) and we need to sign for a public IP,
      // we must configure the signing client with the public endpoint so Host signatures match.
      return new S3Client({
        region: "auto",
        endpoint: publicEndpoint,
        forcePathStyle: isS3Compatible,
        credentials: {
          accessKeyId: accessKeyId || "",
          secretAccessKey: secretAccessKey || "",
        },
      });
    }

    return this.s3Client;
  }

  async incrementReferenceCount(mediaId: string): Promise<void> {
    const metadata = await this.mediaRepo.findOne({ where: { id: mediaId } });
    if (!metadata) {
      throw new Error(`Media ${mediaId} not found`);
    }
    if (metadata.state === "UPLOADING") {
      throw new Error(`Media ${mediaId} upload is not confirmed`);
    }

    metadata.reference_count = (metadata.reference_count || 0) + 1;

    // If state is UPLOADED, ORPHANED or PENDING_DELETE, move it to REFERENCED
    if (
      metadata.state === "UPLOADED" ||
      metadata.state === "ORPHANED" ||
      metadata.state === "PENDING_DELETE"
    ) {
      metadata.state = "REFERENCED";
    }

    // Clear expiration if it was scheduled for deletion
    metadata.expires_at = null;

    await this.mediaRepo.save(metadata);
    this.logger.log(
      `GHOST_LOG: MEDIA_REFERENCE_INCREMENTED: ${mediaId} (refcount=${metadata.reference_count})`,
    );
  }

  async decrementReferenceCount(mediaId: string): Promise<void> {
    const metadata = await this.mediaRepo.findOne({ where: { id: mediaId } });
    if (!metadata) {
      this.logger.warn(`decrementReferenceCount: Media ${mediaId} not found`);
      return;
    }

    metadata.reference_count = Math.max(0, (metadata.reference_count || 0) - 1);

    if (metadata.reference_count === 0) {
      metadata.state = "ORPHANED";
      // Schedule deletion in 1 hour
      const expiresAt = new Date(Date.now() + 60 * 60 * 1000);
      metadata.expires_at = expiresAt;

      await this.auditService.log("MEDIA_ORPHANED", { media_id: mediaId });
      await this.auditService.log("MEDIA_DELETE_SCHEDULED", {
        media_id: mediaId,
        delete_after: expiresAt,
      });
      this.logger.log(
        `GHOST_LOG: MEDIA_ORPHANED: ${mediaId} (Expires at: ${expiresAt.toISOString()})`,
      );
    }

    await this.mediaRepo.save(metadata);
    this.logger.log(
      `GHOST_LOG: MEDIA_REFERENCE_DECREMENTED: ${mediaId} (refcount=${metadata.reference_count})`,
    );
  }

  async deleteMedia(mediaId: string) {
    this.logger.log(`GHOST_LOG: MEDIA_DELETE_START: ${mediaId}`);
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
      await this.auditService.log("media_r2_delete_success", {
        media_id: mediaId,
      });
      await this.auditService.log("MEDIA_R2_DELETE_SUCCESS", {
        media_id: mediaId,
      });
      this.logger.log(`GHOST_LOG: MEDIA_R2_DELETE_SUCCESS: ${mediaId}`);
    } catch (e: any) {
      this.logger.error(
        `Failed to delete media ${mediaId} from R2: ${e?.message || e}`,
      );
    }

    try {
      await this.mediaRepo.delete(mediaId);
      await this.auditService.log("media_metadata_delete_success", {
        media_id: mediaId,
      });
      await this.auditService.log("MEDIA_METADATA_DELETE_SUCCESS", {
        media_id: mediaId,
      });
      this.logger.log(`GHOST_LOG: MEDIA_METADATA_DELETE_SUCCESS: ${mediaId}`);
    } catch (e: any) {
      this.logger.error(
        `Failed to delete media metadata ${mediaId} from Postgres: ${e?.message || e}`,
      );
    }
  }

  async cleanup() {
    this.logger.log("Starting media cleanup worker...");
    const now = new Date();

    // 1. Find expired or orphaned media that has reached its delete schedule
    const expiredOrOrphanedMedia = await this.mediaRepo.find({
      where: [
        { expires_at: LessThan(now) },
        { state: "ORPHANED", expires_at: LessThan(now) },
      ],
    });

    for (const media of expiredOrOrphanedMedia) {
      this.logger.log(
        `Pruning expired/orphaned media: ${media.id} (State: ${media.state})`,
      );
      await this.deleteMedia(media.id);
      await this.auditService.log("media_pruned", {
        media_id: media.id,
        reason: media.state === "ORPHANED" ? "orphaned_expired" : "expired",
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
