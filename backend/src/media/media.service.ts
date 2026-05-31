import { Injectable, Inject, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { S3Client, PutObjectCommand, GetObjectCommand, DeleteObjectCommand } from '@aws-sdk/client-s3';
import { getSignedUrl } from '@aws-sdk/s3-request-presigner';
import Redis from 'ioredis';
import { v4 as uuidv4 } from 'uuid';

@Injectable()
export class MediaService {
  private readonly s3Client: S3Client;
  private readonly bucketName: string;
  private readonly logger = new Logger(MediaService.name);

  constructor(
    private readonly configService: ConfigService,
    @Inject('REDIS_CLIENT') private readonly redis: Redis,
  ) {
    const accountId = this.configService.get<string>('R2_ACCOUNT_ID');
    const accessKeyId = this.configService.get<string>('R2_ACCESS_KEY_ID');
    const secretAccessKey = this.configService.get<string>('R2_SECRET_ACCESS_KEY');
    this.bucketName = this.configService.get<string>('R2_BUCKET_NAME') || 'ghostroom-media';

    this.s3Client = new S3Client({
      region: 'auto',
      endpoint: `https://${accountId}.r2.cloudflarestorage.com`,
      credentials: {
        accessKeyId: accessKeyId || '',
        secretAccessKey: secretAccessKey || '',
      },
    });
  }

  async generateUploadUrl(ownerId: string, size: number, mime: string) {
    const mediaId = uuidv4();
    const expiresAt = Date.now() + 48 * 60 * 60 * 1000; // 48 hours

    const command = new PutObjectCommand({
      Bucket: this.bucketName,
      Key: `media/${mediaId}`,
      ContentLength: size,
      ContentType: mime,
    });

    const uploadUrl = await getSignedUrl(this.s3Client, command, { expiresIn: 3600 }); // URL expires in 1h

    // Store metadata in Redis
    const metadataKey = `media:${mediaId}`;
    await this.redis.hset(metadataKey, {
      owner: ownerId,
      size: size.toString(),
      mime: mime,
      state: 'UPLOADING',
      created_at: Date.now().toString(),
      expires_at: expiresAt.toString(),
    });
    await this.redis.expire(metadataKey, 48 * 60 * 60);

    return { mediaId, uploadUrl };
  }

  async generateDownloadUrl(mediaId: string) {
    const metadata = await this.redis.hgetall(`media:${mediaId}`);
    if (!metadata || Object.keys(metadata).length === 0) {
      throw new Error('Media not found or expired');
    }

    const command = new GetObjectCommand({
      Bucket: this.bucketName,
      Key: `media/${mediaId}`,
    });

    const downloadUrl = await getSignedUrl(this.s3Client, command, { expiresIn: 3600 });
    return { downloadUrl, metadata };
  }

  async updateState(mediaId: string, state: string) {
    const key = `media:${mediaId}`;
    const exists = await this.redis.exists(key);
    if (exists) {
      await this.redis.hset(key, 'state', state);
    }
  }

  async deleteMedia(mediaId: string) {
    try {
      // 1. Delete from R2
      await this.s3Client.send(new DeleteObjectCommand({
        Bucket: this.bucketName,
        Key: `media/${mediaId}`,
      }));
      // Also attempt thumb deletion
      await this.s3Client.send(new DeleteObjectCommand({
        Bucket: this.bucketName,
        Key: `thumbs/${mediaId}`,
      }));
    } catch (e: any) {
      this.logger.error(`Failed to delete media ${mediaId} from R2: ${e?.message || e}`);
    }

    // 2. Delete from Redis
    await this.redis.del(`media:${mediaId}`);
  }

  async cleanup() {
    this.logger.log('Starting media cleanup worker...');
    // In a production environment, you'd scan for expired keys.
    // Since we set Redis TTL, we can use Keyspace Notifications or a manual scan.
    // For simplicity, we'll scan keys.
    const keys = await this.redis.keys('media:*');
    const now = Date.now();

    for (const key of keys) {
      const metadata = await this.redis.hgetall(key);
      const expiresAt = parseInt(metadata.expires_at || '0');
      const state = metadata.state;
      const createdAt = parseInt(metadata.created_at || '0');
      const mediaId = key.split(':')[1];

      // Prune if expired
      if (expiresAt < now) {
        this.logger.log(`Pruning expired media: ${mediaId}`);
        await this.deleteMedia(mediaId);
        continue;
      }

      // Prune if stuck in UPLOADING for > 2 hours
      if (state === 'UPLOADING' && (now - createdAt) > 2 * 60 * 60 * 1000) {
        this.logger.log(`Pruning abandoned upload: ${mediaId}`);
        await this.deleteMedia(mediaId);
      }
    }
  }
}
