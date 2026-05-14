import { Global, Module } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import Redis from 'ioredis';

@Global()
@Module({
  providers: [
    {
      provide: 'REDIS_CLIENT',
      useFactory: (configService: ConfigService) => {
        // Priority: ConfigService -> process.env -> Default
        let url = configService.get<string>('REDIS_URL');
        
        if (!url) {
          console.warn('[Redis Client] REDIS_URL not found in ConfigService. Checking process.env...');
          url = process.env.REDIS_URL;
        }

        if (!url) {
          console.error('[Redis Client] CRITICAL: REDIS_URL environment variable is MISSING.');
          console.warn('[Redis Client] Falling back to: redis://localhost:6379 (This will likely fail in production)');
          url = 'redis://localhost:6379';
        }

        const maskedUrl = url.replace(/:(.*)@/, ':****@');
        console.log(`[Redis Client] Initializing connection to: ${maskedUrl}`);

        const client = new Redis(url, {
          maxRetriesPerRequest: null,
          retryStrategy: (times) => {
            const delay = Math.min(times * 100, 3000);
            return delay;
          },
        });

        client.on('error', (err) => {
          console.error('[Redis Client Error]', err);
        });

        client.on('connect', () => {
          console.log('[Redis Client] Successfully connected');
        });

        return client;
      },
      inject: [ConfigService],
    },
    {
      provide: 'REDIS_SUBSCRIBER',
      useFactory: (configService: ConfigService) => {
        let url = configService.get<string>('REDIS_URL') || process.env.REDIS_URL || 'redis://localhost:6379';
        
        const client = new Redis(url, {
          maxRetriesPerRequest: null,
          retryStrategy: (times) => Math.min(times * 100, 3000),
        });

        client.on('error', (err) => {
          console.error('[Redis Subscriber Error]', err);
        });

        client.on('connect', () => {
          console.log('[Redis Subscriber] Successfully connected');
        });

        return client;
      },
      inject: [ConfigService],
    },
  ],
  exports: ['REDIS_CLIENT', 'REDIS_SUBSCRIBER'],
})
export class RedisModule {}
