import { Module } from "@nestjs/common";
import { TypeOrmModule } from "@nestjs/typeorm";
import { MediaService } from "./media.service";
import { MediaController } from "./media.controller";
import { ScheduleModule, Cron, CronExpression } from "@nestjs/schedule";
import { MediaEntity } from "./entities/media.entity";
import { AuditModule } from "../audit/audit.module";

@Module({
  imports: [
    TypeOrmModule.forFeature([MediaEntity]),
    ScheduleModule.forRoot(),
    AuditModule,
  ],
  controllers: [MediaController],
  providers: [MediaService],
  exports: [MediaService],
})
export class MediaModule {
  constructor(private readonly mediaService: MediaService) {}

  @Cron(CronExpression.EVERY_HOUR)
  handleCleanup() {
    this.mediaService.cleanup();
  }
}
