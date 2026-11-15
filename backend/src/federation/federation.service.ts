import { Injectable, Logger, OnModuleInit } from "@nestjs/common";
import { ConfigService } from "@nestjs/config";
import * as nacl from "tweetnacl";
import bs58 from "bs58";
import { blake2b } from "blakejs";
import * as fs from "fs";
import * as path from "path";
import * as crypto from "crypto";

@Injectable()
export class FederationService implements OnModuleInit {
  private readonly logger = new Logger(FederationService.name);
  private relayKeyPair: nacl.SignKeyPair;
  private relayPublicId: string;

  private readonly homeRelays = new Map<
    string,
    { relayUrl: string; expiresAt: number }
  >();
  private readonly devices = new Map<
    string,
    { deviceIds: Set<string>; expiresAt: number }
  >();
  private readonly deviceRelays = new Map<
    string,
    { relayUrl: string; expiresAt: number }
  >();

  constructor(private readonly configService: ConfigService) {}

  async onModuleInit() {
    const federationEnabled = this.configService.get<string>("FEDERATION_ENABLED") === "true";
    let privKeyBase58 = this.configService.get<string>("RELAY_PRIVATE_KEY");

    if (!privKeyBase58) {
      if (federationEnabled) {
        const errorMsg = "RELAY_PRIVATE_KEY is missing but FEDERATION_ENABLED is true. Federation mode refuses to start without a persistent configured key.";
        this.logger.error(errorMsg);
        throw new Error(errorMsg);
      }

      // Standalone mode: try to load or save relay.key
      const keyFilePath = path.join(process.cwd(), "relay.key");
      if (fs.existsSync(keyFilePath)) {
        try {
          privKeyBase58 = fs.readFileSync(keyFilePath, "utf8").trim();
          this.logger.log(`Loaded persisted relay private key from ${keyFilePath}`);
        } catch (e: any) {
          this.logger.error(`Failed to read persisted relay key file: ${e.message}`);
        }
      }

      if (!privKeyBase58) {
        // Generate new key and persist it
        try {
          const seed = crypto.randomBytes(32);
          privKeyBase58 = bs58.encode(Buffer.from(seed));
          fs.writeFileSync(keyFilePath, privKeyBase58, "utf8");
          this.logger.log(`Generated and persisted new relay private key to ${keyFilePath}`);
        } catch (e: any) {
          this.logger.error(`Failed to persist newly generated relay key: ${e.message}`);
          const ephemeralSeed = crypto.randomBytes(32);
          privKeyBase58 = bs58.encode(Buffer.from(ephemeralSeed));
        }
      }
    }

    try {
      const seed = bs58.decode(privKeyBase58);
      if (seed.length !== 32) {
        throw new Error("Seed must be exactly 32 bytes");
      }
      this.relayKeyPair = nacl.sign.keyPair.fromSeed(seed);
    } catch (e: any) {
      const errorMsg = `Invalid RELAY_PRIVATE_KEY configuration: ${e.message}`;
      this.logger.error(errorMsg);
      throw new Error(errorMsg);
    }

    this.relayPublicId = this.derivePublicId(this.relayKeyPair.publicKey);
    this.logger.log(`Relay Identity: ${this.relayPublicId}`);
  }

  private derivePublicId(publicKey: Uint8Array): string {
    const hash = blake2b(publicKey, null, 32);
    return bs58.encode(Buffer.from(hash));
  }

  getRelayPublicId(): string {
    return this.relayPublicId;
  }

  getPublicKey(): string {
    return bs58.encode(Buffer.from(this.relayKeyPair.publicKey));
  }

  // Registry Methods
  async registerHomeRelay(
    publicId: string,
    relayUrl: string,
    deviceId: string,
  ): Promise<void> {
    const expiresAt = Date.now() + 7 * 86400 * 1000;
    this.homeRelays.set(publicId, { relayUrl, expiresAt });

    const existingDevices = this.devices.get(publicId);
    if (!existingDevices || Date.now() > existingDevices.expiresAt) {
      this.devices.set(publicId, { deviceIds: new Set([deviceId]), expiresAt });
    } else {
      existingDevices.deviceIds.add(deviceId);
      existingDevices.expiresAt = expiresAt;
    }

    this.deviceRelays.set(`${publicId}:${deviceId}`, { relayUrl, expiresAt });

    this.logger.debug(
      `Registered device ${deviceId} for ${publicId} on ${relayUrl}`,
    );
  }

  async getHomeRelay(publicId: string): Promise<string | null> {
    const entry = this.homeRelays.get(publicId);
    if (!entry) return null;
    if (Date.now() > entry.expiresAt) {
      this.homeRelays.delete(publicId);
      return null;
    }
    return entry.relayUrl;
  }

  async getActiveDevices(publicId: string): Promise<string[]> {
    const entry = this.devices.get(publicId);
    if (!entry) return [];
    if (Date.now() > entry.expiresAt) {
      this.devices.delete(publicId);
      return [];
    }
    return Array.from(entry.deviceIds);
  }

  async getDeviceRelay(
    publicId: string,
    deviceId: string,
  ): Promise<string | null> {
    const key = `${publicId}:${deviceId}`;
    const entry = this.deviceRelays.get(key);
    if (!entry) return null;
    if (Date.now() > entry.expiresAt) {
      this.deviceRelays.delete(key);
      return null;
    }
    return entry.relayUrl;
  }

  // Signing for S2S
  signFederationRequest(payload: any): string {
    const message = Buffer.from(JSON.stringify(payload));
    const signature = nacl.sign.detached(message, this.relayKeyPair.secretKey);
    return bs58.encode(Buffer.from(signature));
  }

  verifyFederationSignature(
    payload: any,
    signature: string,
    publicKey: string,
  ): boolean {
    try {
      const message = Buffer.from(JSON.stringify(payload));
      const sigBytes = bs58.decode(signature);
      const pubKeyBytes = bs58.decode(publicKey);
      return nacl.sign.detached.verify(message, sigBytes, pubKeyBytes);
    } catch {
      return false;
    }
  }
}
