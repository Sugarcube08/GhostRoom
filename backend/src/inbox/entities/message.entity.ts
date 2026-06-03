import { Entity, Column, PrimaryColumn, CreateDateColumn } from "typeorm";

@Entity("messages")
export class MessageEntity {
  @PrimaryColumn("uuid")
  id: string;

  @Column("varchar")
  recipient_id: string;

  @Column("varchar", { nullable: true })
  recipient_device_id: string | null;

  @Column("jsonb")
  envelope: Record<string, any>;

  @Column("varchar", { default: "PERSISTENT" })
  retention_mode: string; // 'EPHEMERAL', 'PERSISTENT', 'VIEW_ONCE'

  @CreateDateColumn()
  created_at: Date;

  @Column({
    type: process.env.NODE_ENV === "test" ? "datetime" : "timestamp",
    nullable: true,
  })
  delivered_at: Date | null;

  @Column({
    type: process.env.NODE_ENV === "test" ? "datetime" : "timestamp",
    nullable: true,
  })
  viewed_at: Date | null;

  @Column({
    type: process.env.NODE_ENV === "test" ? "datetime" : "timestamp",
    nullable: true,
  })
  deleted_at: Date | null;

  @Column({
    type: process.env.NODE_ENV === "test" ? "datetime" : "timestamp",
    nullable: true,
  })
  expires_at: Date | null;

  @Column("varchar", { nullable: true })
  media_id: string | null;
}
