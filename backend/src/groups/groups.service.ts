import { Injectable, Inject, Logger } from "@nestjs/common";
import Redis from "ioredis";
import { v4 as uuidv4 } from "uuid";

@Injectable()
export class GroupsService {
  private readonly logger = new Logger(GroupsService.name);

  constructor(@Inject("REDIS_CLIENT") private readonly redis: Redis) {}

  async createGroup(creatorId: string, members: string[]): Promise<string> {
    const groupId = `group_${uuidv4()}`;
    const key = `group:members:${groupId}`;

    // Add creator as member
    const allMembers = Array.from(new Set([creatorId, ...members]));
    await this.redis.sadd(key, ...allMembers);
    await this.redis.expire(key, 86400 * 30); // 30 days default group life if inactive

    this.logger.log(
      `Group created: ${groupId} with ${allMembers.length} members`,
    );
    return groupId;
  }

  async getMembers(groupId: string): Promise<string[]> {
    const key = `group:members:${groupId}`;
    return await this.redis.smembers(key);
  }

  async addMember(groupId: string, publicId: string): Promise<void> {
    const key = `group:members:${groupId}`;
    await this.redis.sadd(key, publicId);
  }

  async removeMember(groupId: string, publicId: string): Promise<void> {
    const key = `group:members:${groupId}`;
    await this.redis.srem(key, publicId);
  }
}
