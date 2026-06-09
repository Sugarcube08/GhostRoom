import { Controller, Get, Post, Body } from "@nestjs/common";
import { InboxService } from "./inbox/inbox.service";

@Controller()
export class AppController {
  constructor(private readonly inboxService: InboxService) {}

  @Get("health")
  getHealth() {
    return { status: "ok", timestamp: new Date().toISOString() };
  }

  @Post("device/register")
  async registerDevice(
    @Body() payload: { identityId: string; platform: string; fcmToken: string },
  ) {
    await this.inboxService.registerDevice(
      payload.identityId,
      payload.platform,
      payload.fcmToken,
    );
    return { success: true };
  }
}
