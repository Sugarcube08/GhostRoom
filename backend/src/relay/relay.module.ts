import { Module } from "@nestjs/common";
import { TypeOrmModule } from "@nestjs/typeorm";
import { RelayGateway } from "./relay.gateway";
import { RoomsModule } from "../rooms/rooms.module";
import { InboxModule } from "../inbox/inbox.module";
import { MediaModule } from "../media/media.module";
import { RelayAuditEntity } from "./entities/relay-audit.entity";
import { AuditService } from "./audit.service";

@Module({
  imports: [
    RoomsModule, 
    InboxModule, 
    MediaModule,
    TypeOrmModule.forFeature([RelayAuditEntity])
  ],
  providers: [RelayGateway, AuditService],
  exports: [AuditService],
})
export class RelayModule {}
