import {
  Entity,
  Column,
  PrimaryGeneratedColumn,
  CreateDateColumn,
} from "typeorm";

@Entity("relay_audit")
export class AuditEntity {
  @PrimaryGeneratedColumn("uuid")
  id: string;

  @Column("varchar")
  event_type: string;

  @CreateDateColumn()
  created_at: Date;

  @Column(process.env.DATABASE_URL ? "jsonb" : "simple-json", { nullable: true })
  metadata: Record<string, any>;
}
