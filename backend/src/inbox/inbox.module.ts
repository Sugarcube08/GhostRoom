import { Module } from '@nestjs/common';
import { InboxService } from './inbox.service';
import { CryptoUtils } from './crypto-utils.service';

@Module({
  providers: [InboxService, CryptoUtils],
  exports: [InboxService, CryptoUtils],
})
export class InboxModule {}
