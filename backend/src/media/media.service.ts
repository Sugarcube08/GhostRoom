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

  private readonly BYTES_LIMIT: number;
  private readonly COUNT_LIMIT: number;

  constructor(
    private readonly configService: ConfigService,
    @Inject('REDIS_CLIENT') private readonly redis: Redis,
  ) {
    const accountId = this.configService.get<string>('R2_ACCOUNT_ID');
    const accessKeyId = this.configService.get<string>('R2_ACCESS_KEY_ID');
    const secretAccessKey = this.configService.get<string>('R2_SECRET_ACCESS_KEY');
    this.bucketName = this.configService.get<string>('R2_BUCKET_NAME') || 'ghostroom-media';

    this.BYTES_LIMIT = parseInt(this.configService.get<string>('MEDIA_DAILY_BYTES_LIMIT') || '104857600');
    this.COUNT_LIMIT = parseInt(this.configService.get<string>('MEDIA_DAILY_COUNT_LIMIT') || '50');

    this.s3Client = new S3Client({
      region: 'auto',
      endpoint: `https://${accountId}.r2.cloudflarestorage.com`,
      credentials: {
        accessKeyId: accessKeyId || '',
        secretAccessKey: secretAccessKey || '',
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

    if (parseInt(currentCount || '0') >= this.COUNT_LIMIT) {
      throw new Error('Daily upload count limit reached');
    }

    if (parseInt(currentBytes || '0') + size > this.BYTES_LIMIT) {
      throw new Error('Daily upload size limit reached');
    }
  }

  async generateUploadUrl(ownerId: string, size: number, mime: string, hash: string) {
    await this.checkQuotas(ownerId, size);

    const mediaId = uuidv4();
    const expiresAt = Date.now() + 48 * 60 * 60 * 1000;

    // 1. Bulk URL
    const bulkCommand = new PutObjectCommand({
      Bucket: this.bucketName,
      Key: `media/${mediaId}`,
      ContentLength: size,
      ContentType: mime,
    });
    const uploadUrl = await getSignedUrl(this.s3Client, bulkCommand, { expiresIn: 3600 });

    // 2. Thumb URL
    const thumbCommand = new PutObjectCommand({
      Bucket: this.bucketName,
      Key: `thumbs/${mediaId}`,
      ContentType: 'image/jpeg',
    });
    const thumbUrl = await getSignedUrl(this.s3Client, thumbCommand, { expiresIn: 3600 });

    // Store metadata
    const bytesKey = `quota:bytes:${ownerId}`;
    const countKey = `quota:count:${ownerId}`;
...
    pipeline.expire(metadataKey, 48 * 60 * 60);

    await pipeline.exec();

    return { mediaId, uploadUrl, thumbUrl };
  }

  async confirmUpload(ownerId: string, mediaId: string) {
    const key = `media:${mediaId}`;
    const metadata = await this.redis.hgetall(key);
    
    if (!metadata || metadata.owner !== ownerId) {
      throw new Error('Forbidden: Not the media owner');
    }

    await this.redis.hset(key, 'state', 'UPLOADED');
  }

  async referenceMedia(ownerId: string, mediaId: string) {
    const key = `media:${mediaId}`;
    const metadata = await this.redis.hgetall(key);
    
    if (!metadata || metadata.owner !== ownerId) {
      throw new Error('Forbidden: Not the media owner');
    }

    if (metadata.state !== 'UPLOADED') {
      throw new Error('Bad Request: Media must be UPLOADED before REFERENCED');
    }

    await this.redis.hset(key, 'state', 'REFERENCED');
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

  async deleteMedia(mediaId: string) {
    try {
      await this.s3Client.send(new DeleteObjectCommand({
        Bucket: this.bucketName,
        Key: `media/${mediaId}`,
      }));
      await this.s3Client.send(new DeleteObjectCommand({
        Bucket: this.bucketName,
        Key: `thumbs/${mediaId}`,
      }));
    } catch (e: any) {
      this.logger.error(`Failed to delete media ${mediaId} from R2: ${e?.message || e}`);
    }
    await this.redis.del(`media:${mediaId}`);
  }

  async cleanup() {
    this.logger.log('Starting media cleanup worker...');
    const keys = await this.redis.keys('media:*');
    const now = Date.now();

    for (const key of keys) {
      const metadata = await this.redis.hgetall(key);
      const expiresAt = parseInt(metadata.expires_at || '0');
      const state = metadata.state;
      const createdAt = parseInt(metadata.created_at || '0');
      const mediaId = key.split(':')[1];

      if (expiresAt < now) {
        this.logger.log(`Pruning expired media: ${mediaId}`);
        await this.deleteMedia(mediaId);
        continue;
      }

      if (state === 'UPLOADING' && (now - createdAt) > 2 * 60 * 60 * 1000) {
        this.logger.log(`Pruning abandoned upload: ${mediaId}`);
        await this.deleteMedia(mediaId);
      }
    }
  }
}
