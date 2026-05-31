import { Module } from "@nestjs/common";
import { RelayGateway } from "./relay.gateway";
import { RoomsModule } from "../rooms/rooms.module";
import { InboxModule } from "../inbox/inbox.module";

@Module({
  imports: [RoomsModule, InboxModule],
  providers: [RelayGateway],
})
export class RelayModule {}
