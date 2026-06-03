import { Module, Global } from "@nestjs/common";
import { GroupsService } from "./groups.service";
import { RedisModule } from "../redis/redis.module";

@Global()
@Module({
  imports: [RedisModule],
  providers: [GroupsService],
  exports: [GroupsService],
})
export class GroupsModule {}
