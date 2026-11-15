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
        if (process.env.NODE_ENV === "test") {
          return {
            type: "better-sqlite3",
            database: ":memory:",
            autoLoadEntities: true,
            synchronize: true,
            dropSchema: true,
          } as any;
        }
        return {
          type: "postgres",
          url: configService.get<string>("DATABASE_URL"),
          autoLoadEntities: true,
          synchronize: true,
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
