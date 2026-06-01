import { Injectable } from "@nestjs/common";
import * as promClient from "prom-client";

@Injectable()
export class MetricsService {
  private readonly registry: promClient.Registry;

  public readonly messagesSent: promClient.Counter;
  public readonly messagesAcked: promClient.Counter;
  public readonly uploadsTotal: promClient.Counter;
  public readonly downloadsTotal: promClient.Counter;
  public readonly rateLimitHits: promClient.Counter;

  constructor() {
    this.registry = new promClient.Registry();
    promClient.collectDefaultMetrics({ register: this.registry });

    this.messagesSent = new promClient.Counter({
      name: "ghostroom_messages_sent_total",
      help: "Total number of messages sent",
      labelNames: ["version"],
    });

    this.messagesAcked = new promClient.Counter({
      name: "ghostroom_messages_ack_total",
      help: "Total number of messages acknowledged",
    });

    this.uploadsTotal = new promClient.Counter({
      name: "ghostroom_uploads_total",
      help: "Total number of media uploads requested",
    });

    this.downloadsTotal = new promClient.Counter({
      name: "ghostroom_downloads_total",
      help: "Total number of media downloads requested",
    });

    this.rateLimitHits = new promClient.Counter({
      name: "ghostroom_rate_limit_hits_total",
      help: "Total number of rate limit rejections",
    });

    this.registry.registerMetric(this.messagesSent);
    this.registry.registerMetric(this.messagesAcked);
    this.registry.registerMetric(this.uploadsTotal);
    this.registry.registerMetric(this.downloadsTotal);
    this.registry.registerMetric(this.rateLimitHits);
  }

  async getMetrics(): Promise<string> {
    return await this.registry.metrics();
  }
}
