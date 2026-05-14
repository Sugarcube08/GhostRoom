import { Controller, Post, Body } from "@nestjs/common";
import { RoomsService } from "./rooms.service";

@Controller("rooms")
export class RoomsController {
  constructor(private readonly roomsService: RoomsService) {}

  @Post()
  async createRoom(@Body() config: { mode?: string; expirySeconds?: number }) {
    const roomId = await this.roomsService.createRoom(config);
    return { roomId };
  }
}
