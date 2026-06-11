import { Injectable, Inject, Logger, OnModuleInit } from "@nestjs/common";
import { ConfigService } from "@nestjs/config";
import Redis from "ioredis";
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

  constructor(
    private readonly configService: ConfigService,
    @Inject("REDIS_CLIENT") private readonly redis: Redis,
  ) {}

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
    const registryKey = `registry:home:${publicId}`;
    const deviceKey = `registry:devices:${publicId}`;

    // Store home relay for the public ID (primary lookup)
    await this.redis.setex(registryKey, 86400 * 7, relayUrl);

    // Track active devices for fan-out
    await this.redis.sadd(deviceKey, deviceId);
    await this.redis.expire(deviceKey, 86400 * 7);

    // Map device to its specific home relay if needed (for roaming devices)
    await this.redis.setex(
      `registry:device_relay:${publicId}:${deviceId}`,
      86400 * 7,
      relayUrl,
    );

    this.logger.debug(
      `Registered device ${deviceId} for ${publicId} on ${relayUrl}`,
    );
  }

  async getHomeRelay(publicId: string): Promise<string | null> {
    const key = `registry:home:${publicId}`;
    return await this.redis.get(key);
  }

  async getActiveDevices(publicId: string): Promise<string[]> {
    const key = `registry:devices:${publicId}`;
    return await this.redis.smembers(key);
  }

  async getDeviceRelay(
    publicId: string,
    deviceId: string,
  ): Promise<string | null> {
    return await this.redis.get(
      `registry:device_relay:${publicId}:${deviceId}`,
    );
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
