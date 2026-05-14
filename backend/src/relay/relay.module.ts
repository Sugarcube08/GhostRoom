import { Module } from "@nestjs/common";
import { RelayGateway } from "./relay.gateway";
import { RoomsModule } from "../rooms/rooms.module";

@Module({
  imports: [RoomsModule],
  providers: [RelayGateway],
})
export class RelayModule {}
