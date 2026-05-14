import { Global, Module } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import Redis from 'ioredis';

@Global()
@Module({
  providers: [
    {
      provide: 'REDIS_CLIENT',
      useFactory: (configService: ConfigService) => {
        console.log('[Redis] Initializing Factory...');
        console.log('[Redis] Available Environment Keys:', Object.keys(process.env).filter(k => !k.toLowerCase().includes('secret') && !k.toLowerCase().includes('key') && !k.toLowerCase().includes('pass')));

        let url = configService.get<string>('REDIS_URL') || process.env.REDIS_URL;
        
        if (!url) {
          console.error('**********************************************************');
          console.error('[Redis Client] CRITICAL ERROR: REDIS_URL IS MISSING!');
          console.error('[Redis Client] Please set REDIS_URL in your environment.');
          console.error('**********************************************************');
          url = 'redis://localhost:6379';
        }

        const maskedUrl = url.replace(/:(.*)@/, ':****@');
        console.log(`[Redis Client] Connecting to: ${maskedUrl}`);

        const options: any = {
          maxRetriesPerRequest: null,
          retryStrategy: (times) => Math.min(times * 100, 3000),
        };

        // Enable TLS for rediss:// URLs (required by most cloud providers)
        if (url.startsWith('rediss://')) {
          console.log('[Redis Client] TLS detected, enabling secure connection options.');
          options.tls = { rejectUnauthorized: false };
        }

        const client = new Redis(url, options);

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
        const url = configService.get<string>('REDIS_URL') || process.env.REDIS_URL || 'redis://localhost:6379';
        
        const options: any = {
          maxRetriesPerRequest: null,
          retryStrategy: (times) => Math.min(times * 100, 3000),
        };

        if (url.startsWith('rediss://')) {
          options.tls = { rejectUnauthorized: false };
        }

        const client = new Redis(url, options);

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
