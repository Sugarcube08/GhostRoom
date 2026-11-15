import { Module, Global } from "@nestjs/common";
import { FederationService } from "./federation.service";

@Global()
@Module({
  providers: [FederationService],
  exports: [FederationService],
})
export class FederationModule {}
