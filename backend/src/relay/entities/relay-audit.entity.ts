import { Entity, Column, PrimaryGeneratedColumn, CreateDateColumn } from 'typeorm';

@Entity('relay_audit')
export class RelayAuditEntity {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column('varchar')
  event_type: string;

  @CreateDateColumn()
  created_at: Date;

  @Column('jsonb', { nullable: true })
  metadata: Record<string, any>;
}
