import { Global, Module, OnModuleDestroy } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import Redis from 'ioredis';

@Global()
@Module({
  providers: [
    {
      provide: 'REDIS_CLIENT',
      useFactory: (configService: ConfigService) => {
        const url = configService.get<string>('REDIS_URL') || process.env.REDIS_URL;
        
        if (!url) {
          console.error('❌ [Redis Client] CRITICAL ERROR: REDIS_URL environment variable is not set!');
          console.warn('⚠️ [Redis Client] Falling back to redis://localhost:6379 (this will likely fail in Docker)');
        }

        const redisUrl = url || 'redis://localhost:6379';
        const maskedUrl = redisUrl.replace(/:(.*)@/, ':****@');
        console.log(`🚀 [Redis Client] Attempting connection to: ${maskedUrl}`);

        const options: any = {
          maxRetriesPerRequest: null,
          retryStrategy: (times) => {
            const delay = Math.min(times * 200, 5000);
            console.log(`🔄 [Redis Client] Connection retry #${times} in ${delay}ms...`);
            return delay;
          },
          reconnectOnError: (err) => {
            const targetError = 'READONLY';
            if (err.message.includes(targetError)) {
              return true;
            }
            return false;
          },
        };

        if (redisUrl.startsWith('rediss://')) {
          options.tls = { rejectUnauthorized: false };
        }

        const client = new Redis(redisUrl, options);

        client.on('error', (err) => {
          console.error('❌ [Redis Client Error]', err.message);
        });

        client.on('connect', () => {
          console.log('✅ [Redis Client] Connected successfully');
        });

        client.on('ready', () => {
          console.log('✨ [Redis Client] Ready to handle commands');
        });

        return client;
      },
      inject: [ConfigService],
    },
    {
      provide: 'REDIS_SUBSCRIBER',
      useFactory: (configService: ConfigService) => {
        const url = configService.get<string>('REDIS_URL') || process.env.REDIS_URL;
        const redisUrl = url || 'redis://localhost:6379';
        
        console.log(`🚀 [Redis Subscriber] Attempting connection to: ${redisUrl.replace(/:(.*)@/, ':****@')}`);

        const options: any = {
          maxRetriesPerRequest: null,
          retryStrategy: (times) => Math.min(times * 200, 5000),
        };

        if (redisUrl.startsWith('rediss://')) {
          options.tls = { rejectUnauthorized: false };
        }

        const client = new Redis(redisUrl, options);

        client.on('error', (err) => {
          console.error('❌ [Redis Subscriber Error]', err.message);
        });

        client.on('connect', () => {
          console.log('✅ [Redis Subscriber] Connected successfully');
        });

        return client;
      },
      inject: [ConfigService],
    },
  ],
  exports: ['REDIS_CLIENT', 'REDIS_SUBSCRIBER'],
})
export class RedisModule {}
