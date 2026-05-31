import { Entity, Column, PrimaryColumn, CreateDateColumn } from 'typeorm';

@Entity('messages')
export class MessageEntity {
  @PrimaryColumn('uuid')
  id: string;

  @Column('varchar')
  recipient_id: string;

  @Column('jsonb')
  envelope: Record<string, any>;

  @CreateDateColumn()
  created_at: Date;

  @Column({ type: process.env.NODE_ENV === 'test' ? 'datetime' : 'timestamp', nullable: true })
  expires_at: Date | null;
}
