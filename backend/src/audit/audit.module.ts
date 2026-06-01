import { Module } from "@nestjs/common";
import { TypeOrmModule } from "@nestjs/typeorm";
import { AuditEntity } from "./entities/audit.entity";
import { AuditService } from "./audit.service";

@Module({
  imports: [TypeOrmModule.forFeature([AuditEntity])],
  providers: [AuditService],
  exports: [AuditService],
})
export class AuditModule {}
