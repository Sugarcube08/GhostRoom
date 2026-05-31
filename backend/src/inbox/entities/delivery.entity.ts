import { Entity, Column, PrimaryColumn, UpdateDateColumn } from 'typeorm';

@Entity('message_delivery')
export class DeliveryEntity {
  @PrimaryColumn('uuid')
  message_id: string;

  @Column('varchar')
  recipient_id: string;

  @Column('varchar', { default: 'PENDING' })
  status: string;

  @UpdateDateColumn()
  updated_at: Date;
}
