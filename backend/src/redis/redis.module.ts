import { Global, Module } from "@nestjs/common";
import { ConfigService } from "@nestjs/config";
import Redis from "ioredis";

@Global()
@Module({
  providers: [
    {
      provide: "REDIS_CLIENT",
      useFactory: (configService: ConfigService) => {
        console.log("🔍 [Redis Debug] --- ENVIRONMENT AUDIT ---");

        const urlSources = {
          ENV_REDIS_URL: process.env.REDIS_URL,
          ENV_REDIS_INTERNAL_URL: process.env.REDIS_INTERNAL_URL,
          CONFIG_REDIS_URL: configService.get<string>("REDIS_URL"),
        };

        for (const [key, value] of Object.entries(urlSources)) {
          if (value) {
            console.log(
              `🔍 [Redis Debug] Found ${key}: ${value.replace(/:(.*)@/, ":****@")}`,
            );
          }
        }

        // Prioritize internal URL on Render, then standard URL
        let finalUrl =
          process.env.REDIS_INTERNAL_URL ||
          process.env.REDIS_URL ||
          configService.get<string>("REDIS_URL");

        // Block localhost on Render
        if (process.env.RENDER === "true" && finalUrl?.includes("localhost")) {
          console.log(
            '❌ [Redis Debug] ERROR: Detected "localhost" URL on Render! This is invalid.',
          );
          console.log(
            "👉 ACTION REQUIRED: Go to Render Dashboard and set REDIS_URL to your Internal Redis URL.",
          );
          finalUrl = undefined;
        }

        if (!finalUrl) {
          console.log(
            "❌ [Redis Debug] ERROR: No Redis URL found! Connection will fail.",
          );
          // Use a dummy string to prevent ioredis from crashing immediately, but it won't connect.
          finalUrl = "redis://invalid-host-missing-config:6379";
        }

        console.log(
          `🚀 [Redis Client] Final Connection: ${finalUrl.replace(/:(.*)@/, ":****@")}`,
        );

        const options: any = {
          maxRetriesPerRequest: null,
          retryStrategy: (times) => {
            // Stop retrying if the URL is obviously wrong
            if (
              finalUrl?.includes("invalid-host") ||
              (finalUrl?.includes("localhost") && process.env.RENDER === "true")
            )
              return null;
            return Math.min(times * 500, 5000);
          },
        };

        if (finalUrl.startsWith("rediss://")) {
          console.log("🔒 [Redis Client] TLS Enabled");
          options.tls = { rejectUnauthorized: false };
        }

        const client = new Redis(finalUrl, options);
        client.on("error", (err) =>
          console.error("❌ [Redis Client Error]", err.message),
        );
        client.on("connect", () => console.log("✅ [Redis Client] Connected"));

        return client;
      },
      inject: [ConfigService],
    },
    {
      provide: "REDIS_SUBSCRIBER",
      useFactory: (configService: ConfigService) => {
        const finalUrl =
          process.env.REDIS_INTERNAL_URL ||
          process.env.REDIS_URL ||
          configService.get<string>("REDIS_URL") ||
          "redis://invalid-host:6379";

        const options: any = {
          maxRetriesPerRequest: null,
          retryStrategy: (times) => {
            if (finalUrl?.includes("invalid-host")) return null;
            return Math.min(times * 500, 5000);
          },
        };

        if (finalUrl.startsWith("rediss://")) {
          options.tls = { rejectUnauthorized: false };
        }

        const client = new Redis(finalUrl, options);
        client.on("error", (err) =>
          console.error("❌ [Redis Subscriber Error]", err.message),
        );
        client.on("connect", () =>
          console.log("✅ [Redis Subscriber] Connected"),
        );

        return client;
      },
      inject: [ConfigService],
    },
  ],
  exports: ["REDIS_CLIENT", "REDIS_SUBSCRIBER"],
})
export class RedisModule {}
