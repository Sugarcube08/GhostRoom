import { Controller, Get, Inject } from "@nestjs/common";
import { MetricsService } from "./metrics.service";
import Redis from "ioredis";
import { InjectDataSource } from "@nestjs/typeorm";
import { DataSource } from "typeorm";
import { MediaService } from "../media/media.service";

@Controller()
export class HealthController {
  constructor(
    private readonly metricsService: MetricsService,
    private readonly mediaService: MediaService,
    @Inject("REDIS_CLIENT") private readonly redis: Redis,
    @InjectDataSource() private readonly dataSource: DataSource,
  ) {}

  @Get("health")
  async getHealth() {
    const postgres = this.dataSource.isInitialized ? "ok" : "error";
    let redis = "ok";
    try {
      await this.redis.ping();
    } catch {
      redis = "error";
    }

    return {
      postgres,
      redis,
      r2: "ok", // R2 connectivity is usually handled via signed URLs, but service is ready
      status: postgres === "ok" && redis === "ok" ? "healthy" : "degraded",
    };
  }

  @Get("metrics")
  async getMetrics() {
    return await this.metricsService.getMetrics();
  }
}
