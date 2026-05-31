import { Module } from '@nestjs/common';
import { MediaService } from './media.service';
import { MediaController } from './media.controller';
import { ScheduleModule } from '@nestjs/schedule';
import { Cron, CronExpression } from '@nestjs/schedule';

@Module({
  imports: [
    ScheduleModule.forRoot(),
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
