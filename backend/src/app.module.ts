import { Module } from "@nestjs/common";
import { ConfigModule, ConfigService } from "@nestjs/config";
import { TypeOrmModule } from "@nestjs/typeorm";
import { RelayModule } from "./relay/relay.module";
import { InboxModule } from "./inbox/inbox.module";
import { MediaModule } from "./media/media.module";
import { AuditModule } from "./audit/audit.module";
import { FederationModule } from "./federation/federation.module";
import { AppController } from "./app.controller";

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
  controllers: [AppController],
})
export class AppModule {}
