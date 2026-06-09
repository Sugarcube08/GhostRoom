import { Entity, Column, PrimaryColumn, UpdateDateColumn } from "typeorm";

@Entity("devices")
export class DeviceEntity {
  @PrimaryColumn("varchar")
  identity_id: string;

  @Column("varchar")
  fcm_token: string;

  @Column("varchar", { default: "android" })
  platform: string;

  @UpdateDateColumn()
  updated_at: Date;
}
