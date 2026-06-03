import { Module } from "@nestjs/common";
import { TypeOrmModule } from "@nestjs/typeorm";
import { InboxService } from "./inbox.service";
import { CryptoUtils } from "./crypto-utils.service";
import { MessageEntity } from "./entities/message.entity";
import { DeliveryEntity } from "./entities/delivery.entity";
import { MediaModule } from "../media/media.module";

@Module({
  imports: [
    TypeOrmModule.forFeature([MessageEntity, DeliveryEntity]),
    MediaModule,
  ],
  providers: [InboxService, CryptoUtils],
  exports: [InboxService, CryptoUtils],
})
export class InboxModule {}
