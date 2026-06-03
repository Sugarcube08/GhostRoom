import { Module, Global } from "@nestjs/common";
import { FederationService } from "./federation.service";
import { RedisModule } from "../redis/redis.module";

@Global()
@Module({
  imports: [RedisModule],
  providers: [FederationService],
  exports: [FederationService],
})
export class FederationModule {}
