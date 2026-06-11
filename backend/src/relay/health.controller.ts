import { Controller, Get, Inject, HttpException, HttpStatus } from "@nestjs/common";
import { MetricsService } from "./metrics.service";
import Redis from "ioredis";
import { InjectDataSource } from "@nestjs/typeorm";
import { DataSource } from "typeorm";
import { MediaService } from "../media/media.service";
import { InboxService } from "../inbox/inbox.service";
import { FederationService } from "../federation/federation.service";
import { RelayGateway } from "./relay.gateway";
import { FirebaseService } from "../inbox/firebase.service";

@Controller()
export class HealthController {
  constructor(
    private readonly metricsService: MetricsService,
    private readonly mediaService: MediaService,
    private readonly inboxService: InboxService,
    private readonly federationService: FederationService,
    private readonly relayGateway: RelayGateway,
    private readonly firebaseService: FirebaseService,
    @Inject("REDIS_CLIENT") private readonly redis: Redis,
    @InjectDataSource() private readonly dataSource: DataSource,
  ) {}

  @Get("health")
  async getHealth() {
    let databaseStatus = "ok";
    let redisStatus = "ok";
    let fcmStatus = "ok";
    let storageStatus = "ok";
    let relayStatus = "ok";
    let websocketStatus = "ok";
    let overallStatus = "healthy";

    try {
      await this.dataSource.query("SELECT 1");
    } catch {
      databaseStatus = "error";
      overallStatus = "degraded";
    }

    try {
      await this.redis.ping();
    } catch {
      redisStatus = "error";
      overallStatus = "degraded";
    }

    try {
      if (this.firebaseService.getFcmEnabled() && !this.firebaseService.getApp()) {
        throw new Error("FCM is enabled but Firebase app is not initialized");
      }
    } catch {
      fcmStatus = "error";
      overallStatus = "degraded";
    }

    try {
      const { ListObjectsV2Command } = await import("@aws-sdk/client-s3");
      await this.mediaService["s3Client"].send(
        new ListObjectsV2Command({
          Bucket: this.mediaService["bucketName"] || "ghostroom-media",
          MaxKeys: 1,
        }),
      );
    } catch {
      storageStatus = "error";
      overallStatus = "degraded";
    }

    try {
      const testPayload = { test: "health-check", timestamp: Date.now() };
      const signature = this.federationService.signFederationRequest(testPayload);
      const isValid = this.federationService.verifyFederationSignature(
        testPayload,
        signature,
        this.federationService.getPublicKey(),
      );
      if (!isValid) throw new Error();
    } catch {
      relayStatus = "error";
      overallStatus = "degraded";
    }

    try {
      if (!this.relayGateway.server) throw new Error();
    } catch {
      websocketStatus = "error";
      overallStatus = "degraded";
    }

    const response = {
      status: overallStatus,
      postgres: databaseStatus,
      redis: redisStatus,
      fcm: fcmStatus,
      storage: storageStatus,
      relay: relayStatus,
      websocket: websocketStatus,
    };

    if (overallStatus === "degraded") {
      throw new HttpException(response, HttpStatus.SERVICE_UNAVAILABLE);
    }

    return response;
  }

  @Get("health/database")
  async getDatabaseHealth() {
    try {
      if (!this.dataSource.isInitialized) {
        throw new Error("Database datasource is not initialized");
      }
      await this.dataSource.query("SELECT 1");
      return {
        status: "ok",
        type: this.dataSource.options.type,
      };
    } catch (err: any) {
      throw new HttpException(
        { status: "error", message: `Database is unhealthy: ${err.message}` },
        HttpStatus.INTERNAL_SERVER_ERROR,
      );
    }
  }

  @Get("health/fcm")
  async getFcmHealth() {
    try {
      if (!this.firebaseService.getFcmEnabled()) {
        return {
          initialized: false,
          projectId: "FCM_DISABLED",
          credentialSource: "none",
        };
      }
      const app = this.firebaseService.getApp();
      if (!app) {
        throw new Error("Firebase Admin SDK not initialized");
      }
      return {
        initialized: true,
        projectId: this.firebaseService.getProjectId(),
        credentialSource: this.firebaseService.getCredentialSource(),
      };
    } catch (err: any) {
      throw new HttpException(
        { status: "error", message: err.message },
        HttpStatus.INTERNAL_SERVER_ERROR,
      );
    }
  }

  @Get("health/storage")
  async getStorageHealth() {
    try {
      const bucketName = this.mediaService["bucketName"] || "ghostroom-media";
      const { ListObjectsV2Command } = await import("@aws-sdk/client-s3");
      await this.mediaService["s3Client"].send(
        new ListObjectsV2Command({
          Bucket: bucketName,
          MaxKeys: 1,
        }),
      );
      return {
        status: "ok",
        bucket: bucketName,
      };
    } catch (err: any) {
      throw new HttpException(
        { status: "error", message: `Storage health check failed: ${err.message}` },
        HttpStatus.INTERNAL_SERVER_ERROR,
      );
    }
  }

  @Get("health/relay")
  async getRelayHealth() {
    try {
      const testPayload = { test: "health-check", timestamp: Date.now() };
      const signature = this.federationService.signFederationRequest(testPayload);
      const isValid = this.federationService.verifyFederationSignature(
        testPayload,
        signature,
        this.federationService.getPublicKey(),
      );
      if (!isValid) {
        throw new Error("Relay cryptographic signature self-check failed");
      }
      return {
        status: "ok",
        publicId: this.federationService.getRelayPublicId(),
        publicKey: this.federationService.getPublicKey(),
        federationEnabled: this.federationService["configService"].get<string>("FEDERATION_ENABLED") === "true",
        persistent: true,
      };
    } catch (err: any) {
      throw new HttpException(
        { status: "error", message: `Relay identity is unhealthy: ${err.message}` },
        HttpStatus.INTERNAL_SERVER_ERROR,
      );
    }
  }

  @Get("health/websocket")
  async getWebsocketHealth() {
    try {
      if (!this.relayGateway.server) {
        throw new Error("WebSocket gateway server is not initialized");
      }
      const clientCount = this.relayGateway.server.sockets.sockets.size;
      return {
        status: "ok",
        clientCount,
      };
    } catch (err: any) {
      throw new HttpException(
        { status: "error", message: `WebSocket gateway is unhealthy: ${err.message}` },
        HttpStatus.INTERNAL_SERVER_ERROR,
      );
    }
  }

  @Get("metrics")
  async getMetrics() {
    return await this.metricsService.getMetrics();
  }
}
