import { Global, Module } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import Redis from 'ioredis';

@Global()
@Module({
  providers: [
    {
      provide: 'REDIS_CLIENT',
      useFactory: (configService: ConfigService) => {
        console.log('🔍 [Redis Client Debug] --- ENVIRONMENT AUDIT ---');
        
        const envs = {
          'process.env.REDIS_URL': process.env.REDIS_URL,
          'process.env.REDIS_INTERNAL_URL': process.env.REDIS_INTERNAL_URL,
          'process.env.REDIS_EXTERNAL_URL': process.env.REDIS_EXTERNAL_URL,
          'ConfigService.REDIS_URL': configService.get<string>('REDIS_URL'),
        };

        for (const [key, value] of Object.entries(envs)) {
          if (value) {
            const masked = value.replace(/:(.*)@/, ':****@');
            console.log(`🔍 [Redis Client Debug] ${key}: ${masked}`);
          } else {
            console.log(`🔍 [Redis Client Debug] ${key}: MISSING`);
          }
        }

        // Priority Logic
        let selectedUrl = process.env.REDIS_URL || process.env.REDIS_INTERNAL_URL || process.env.REDIS_EXTERNAL_URL || configService.get<string>('REDIS_URL');

        // Render-specific Fix:
        // If we are on Render and the URL is localhost, it's definitely wrong.
        if (process.env.RENDER === 'true' && selectedUrl?.includes('localhost')) {
          console.log('⚠️ [Redis Client Debug] DETECTED LOCALHOST ON RENDER. Proactively searching for Internal URL...');
          selectedUrl = process.env.REDIS_INTERNAL_URL || process.env.REDIS_URL;
          
          if (selectedUrl?.includes('localhost')) {
             console.log('❌ [Redis Client Debug] Still localhost. Reverting to undefined to trigger retry logic or fallback.');
             selectedUrl = undefined;
          }
        }

        const finalUrl = selectedUrl || 'redis://localhost:6379';
        console.log(`🚀 [Redis Client] Final choice: ${finalUrl.replace(/:(.*)@/, ':****@')}`);

        const options: any = {
          maxRetriesPerRequest: null,
          retryStrategy: (times) => Math.min(times * 500, 5000),
        };

        if (finalUrl.startsWith('rediss://')) {
          console.log('🔒 [Redis Client] TLS Enabled');
          options.tls = { rejectUnauthorized: false };
        }

        const client = new Redis(finalUrl, options);
        client.on('error', (err) => console.error('❌ [Redis Client Error]', err.message));
        client.on('connect', () => console.log('✅ [Redis Client] Connected'));
        
        return client;
      },
      inject: [ConfigService],
    },
    {
      provide: 'REDIS_SUBSCRIBER',
      useFactory: (configService: ConfigService) => {
        const finalUrl = process.env.REDIS_URL || process.env.REDIS_INTERNAL_URL || configService.get<string>('REDIS_URL') || 'redis://localhost:6379';
        
        const options: any = {
          maxRetriesPerRequest: null,
          retryStrategy: (times) => Math.min(times * 500, 5000),
        };

        if (finalUrl.startsWith('rediss://')) {
          options.tls = { rejectUnauthorized: false };
        }

        const client = new Redis(finalUrl, options);
        client.on('error', (err) => console.error('❌ [Redis Subscriber Error]', err.message));
        client.on('connect', () => console.log('✅ [Redis Subscriber] Connected'));
        
        return client;
      },
      inject: [ConfigService],
    },
  ],
  exports: ['REDIS_CLIENT', 'REDIS_SUBSCRIBER'],
})
export class RedisModule {}
