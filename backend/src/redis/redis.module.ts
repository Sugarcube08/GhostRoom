import { Global, Module } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import Redis from 'ioredis';

@Global()
@Module({
  providers: [
    {
      provide: 'REDIS_CLIENT',
      useFactory: (configService: ConfigService) => {
        console.log('🔍 [Redis Client Debug] STARTING INITIALIZATION');
        
        // Render often provides REDIS_URL or REDIS_INTERNAL_URL.
        // We prioritize raw process.env because NestJS ConfigService might be 
        // shadowed by .env files or .env.example templates.
        const rawUrl = process.env.REDIS_URL || process.env.REDIS_INTERNAL_URL || process.env.REDIS_EXTERNAL_URL;
        const configUrl = configService.get<string>('REDIS_URL');

        console.log(`🔍 [Redis Client Debug] Raw process.env URL: ${rawUrl ? 'DETECTED' : 'MISSING'}`);
        console.log(`🔍 [Redis Client Debug] Nest ConfigService URL: ${configUrl ? 'DETECTED' : 'MISSING'}`);

        // If Render provides a real URL, use it. Never fallback if a real one exists.
        const finalUrl = rawUrl || configUrl || 'redis://localhost:6379';
        
        if (finalUrl.includes('localhost') && (rawUrl || configUrl)) {
          console.log('⚠️ [Redis Client Debug] WARNING: One of the URLs contains localhost but we found env vars. Checking for shadowing...');
        }

        const maskedUrl = finalUrl.replace(/:(.*)@/, ':****@');
        console.log(`🚀 [Redis Client] Final Connection String: ${maskedUrl}`);

        const options: any = {
          maxRetriesPerRequest: null,
          retryStrategy: (times) => {
            const delay = Math.min(times * 500, 5000);
            return delay;
          },
        };

        if (finalUrl.startsWith('rediss://')) {
          console.log('🔒 [Redis Client] TLS/SSL detected');
          options.tls = { rejectUnauthorized: false };
        }

        return new Redis(finalUrl, options);
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

        return new Redis(finalUrl, options);
      },
      inject: [ConfigService],
    },
  ],
  exports: ['REDIS_CLIENT', 'REDIS_SUBSCRIBER'],
})
export class RedisModule {}
