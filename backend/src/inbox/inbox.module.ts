import { Module } from "@nestjs/common";
import { TypeOrmModule } from "@nestjs/typeorm";
import { InboxService } from "./inbox.service";
import { CryptoUtils } from "./crypto-utils.service";
import { FirebaseService } from "./firebase.service";
import { MessageEntity } from "./entities/message.entity";
import { DeliveryEntity } from "./entities/delivery.entity";
import { DeviceEntity } from "./entities/device.entity";
import { MediaModule } from "../media/media.module";

@Module({
  imports: [
    TypeOrmModule.forFeature([MessageEntity, DeliveryEntity, DeviceEntity]),
    MediaModule,
  ],
  providers: [InboxService, CryptoUtils, FirebaseService],
  exports: [InboxService, CryptoUtils, FirebaseService],
})
export class InboxModule {}
