import { Entity, Column, PrimaryGeneratedColumn, UpdateDateColumn } from "typeorm";

@Entity("message_delivery")
export class DeliveryEntity {
  @PrimaryGeneratedColumn("uuid")
  id: string;

  @Column("uuid")
  message_id: string;

  @Column("varchar")
  recipient_id: string;

  @Column("varchar", { nullable: true })
  recipient_device_id: string | null;

  @Column("varchar", { nullable: true })
  sender_id: string;

  @Column("varchar", { default: "PENDING" })
  status: string;

  @UpdateDateColumn()
  updated_at: Date;
}
