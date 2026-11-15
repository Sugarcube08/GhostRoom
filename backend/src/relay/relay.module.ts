import { Module } from "@nestjs/common";
import { RelayGateway } from "./relay.gateway";
import { InboxModule } from "../inbox/inbox.module";
import { MediaModule } from "../media/media.module";
import { AuditModule } from "../audit/audit.module";
import { MetricsService } from "./metrics.service";
import { HealthController } from "./health.controller";

@Module({
  imports: [InboxModule, MediaModule, AuditModule],
  controllers: [HealthController],
  providers: [RelayGateway, MetricsService],
  exports: [MetricsService],
})
export class RelayModule {}
