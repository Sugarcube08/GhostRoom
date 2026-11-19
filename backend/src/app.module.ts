import { Module } from "@nestjs/common";
import { ConfigModule, ConfigService } from "@nestjs/config";
import { TypeOrmModule } from "@nestjs/typeorm";
import { RelayModule } from "./relay/relay.module";
import { InboxModule } from "./inbox/inbox.module";
import { MediaModule } from "./media/media.module";
import { AuditModule } from "./audit/audit.module";
import { FederationModule } from "./federation/federation.module";
import { AppController } from "./app.controller";
import { PortalController } from "./portal/portal.controller";

import { ThrottlerModule } from "@nestjs/throttler";

@Module({
  imports: [
    ConfigModule.forRoot({
      isGlobal: true,
    }),
    TypeOrmModule.forRootAsync({
      inject: [ConfigService],
      useFactory: (configService: ConfigService) => {
        const dbUrl = configService.get<string>("DATABASE_URL");
        if (process.env.NODE_ENV === "test") {
          return {
            type: "better-sqlite3",
            database: ":memory:",
            autoLoadEntities: true,
            synchronize: true,
            dropSchema: true,
          } as any;
        }

        if (!dbUrl) {
          console.warn(
            "⚠️ DATABASE_URL is not configured! Defaulting to local in-memory SQLite store.",
          );
          return {
            type: "better-sqlite3",
            database: ":memory:",
            autoLoadEntities: true,
            synchronize: true,
            retryAttempts: 1,
          } as any;
        }

        const isDockerHost = dbUrl.includes("@postgres:") || dbUrl.includes("@postgres/");
        if (isDockerHost && (process.env.VERCEL || process.env.AWS_LAMBDA_FUNCTION_NAME)) {
          console.warn(
            "⚠️ DATABASE_URL points to internal Docker host 'postgres' which is unreachable in cloud serverless environment. Falling back to local in-memory SQLite store.",
          );
          return {
            type: "better-sqlite3",
            database: ":memory:",
            autoLoadEntities: true,
            synchronize: true,
            retryAttempts: 1,
          } as any;
        }

        const isSsl =
          dbUrl.includes("sslmode=require") ||
          process.env.DATABASE_SSL === "true" ||
          process.env.NODE_ENV === "production";

        return {
          type: "postgres",
          url: dbUrl,
          autoLoadEntities: true,
          synchronize: true,
          retryAttempts: 2,
          retryDelay: 1000,
          extra: isSsl ? { ssl: { rejectUnauthorized: false } } : undefined,
        } as any;
      },
    }),
    ThrottlerModule.forRoot([
      {
        ttl: 60000,
        limit: 10,
      },
    ]),
    RelayModule,
    InboxModule,
    MediaModule,
    AuditModule,
    FederationModule,
  ],
  controllers: [AppController, PortalController],
})
export class AppModule {}
