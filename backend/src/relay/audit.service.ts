import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { RelayAuditEntity } from './entities/relay-audit.entity';

@Injectable()
export class AuditService {
  constructor(
    @InjectRepository(RelayAuditEntity)
    private readonly auditRepo: Repository<RelayAuditEntity>,
  ) {}

  async log(eventType: string, metadata?: Record<string, any>): Promise<void> {
    const audit = this.auditRepo.create({
      event_type: eventType,
      metadata: metadata,
    });
    await this.auditRepo.save(audit);
  }
}
