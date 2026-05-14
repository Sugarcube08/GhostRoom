import { Global, Module } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import Redis from 'ioredis';

@Global()
@Module({
  providers: [
    {
      provide: 'REDIS_CLIENT',
      useFactory: (configService: ConfigService) => {
        console.log('🔍 [Redis Client Debug] Initializing Redis Client...');
        
        // Debug environment variables
        const configUrl = configService.get<string>('REDIS_URL');
        const envUrl = process.env.REDIS_URL;
        const internalUrl = process.env.REDIS_INTERNAL_URL;
        const externalUrl = process.env.REDIS_EXTERNAL_URL;
        
        console.log(`🔍 [Redis Client Debug] ConfigService REDIS_URL: ${configUrl ? 'FOUND' : 'NOT FOUND'}`);
        console.log(`🔍 [Redis Client Debug] process.env.REDIS_URL: ${envUrl ? 'FOUND' : 'NOT FOUND'}`);
        console.log(`🔍 [Redis Client Debug] process.env.REDIS_INTERNAL_URL: ${internalUrl ? 'FOUND' : 'NOT FOUND'}`);
        console.log(`🔍 [Redis Client Debug] process.env.REDIS_EXTERNAL_URL: ${externalUrl ? 'FOUND' : 'NOT FOUND'}`);

        const url = configUrl || envUrl || internalUrl || externalUrl;
        
        if (!url) {
          console.log('⚠️ [Redis Client] WARNING: No REDIS_URL found in environment! Falling back to localhost:6379');
        }

        const redisUrl = url || 'redis://localhost:6379';
        const maskedUrl = redisUrl.replace(/:(.*)@/, ':****@');
        console.log(`🚀 [Redis Client] Connecting to: ${maskedUrl}`);

        const options: any = {
          maxRetriesPerRequest: null,
          retryStrategy: (times) => {
            const delay = Math.min(times * 500, 5000);
            console.log(`🔄 [Redis Client] Retry #${times} in ${delay}ms...`);
            return delay;
          },
        };

        if (redisUrl.startsWith('rediss://')) {
          console.log('🔒 [Redis Client] Using secure connection (TLS)');
          options.tls = { rejectUnauthorized: false };
        }

        const client = new Redis(redisUrl, options);

        client.on('error', (err) => {
          console.log(`❌ [Redis Client Error] ${err.message}`);
        });

        client.on('connect', () => {
          console.log('✅ [Redis Client] Connected');
        });

        return client;
      },
      inject: [ConfigService],
    },
    {
      provide: 'REDIS_SUBSCRIBER',
      useFactory: (configService: ConfigService) => {
        const url = configService.get<string>('REDIS_URL') || process.env.REDIS_URL || process.env.REDIS_INTERNAL_URL;
        const redisUrl = url || 'redis://localhost:6379';
        
        const options: any = {
          maxRetriesPerRequest: null,
          retryStrategy: (times) => Math.min(times * 500, 5000),
        };

        if (redisUrl.startsWith('rediss://')) {
          options.tls = { rejectUnauthorized: false };
        }

        const client = new Redis(redisUrl, options);

        client.on('error', (err) => {
          console.log(`❌ [Redis Subscriber Error] ${err.message}`);
        });

        client.on('connect', () => {
          console.log('✅ [Redis Subscriber] Connected');
        });

        return client;
      },
      inject: [ConfigService],
    },
  ],
  exports: ['REDIS_CLIENT', 'REDIS_SUBSCRIBER'],
})
export class RedisModule {}
