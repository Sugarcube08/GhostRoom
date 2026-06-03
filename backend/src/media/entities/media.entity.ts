import { Entity, Column, PrimaryColumn, CreateDateColumn } from "typeorm";

@Entity("media_metadata")
export class MediaEntity {
  @PrimaryColumn("uuid")
  id: string;

  @Column("varchar", { nullable: true })
  owner_id: string;

  @Column("bigint", { nullable: true })
  size_bytes: string; // TypeORM maps bigint to string in JS to avoid precision loss

  @Column("varchar", { nullable: true })
  mime_type: string;

  @Column("varchar", { nullable: true })
  content_hash: string;

  @Column("varchar", { default: "UPLOADING" })
  state: string;

  @CreateDateColumn()
  created_at: Date;

  @Column({
    type: process.env.NODE_ENV === "test" ? "datetime" : "timestamp",
    nullable: true,
  })
  expires_at: Date | null;

  @Column("integer", { default: 0 })
  reference_count: number;
}
