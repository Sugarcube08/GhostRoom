"use strict";
var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
var __metadata = (this && this.__metadata) || function (k, v) {
    if (typeof Reflect === "object" && typeof Reflect.metadata === "function") return Reflect.metadata(k, v);
};
var __param = (this && this.__param) || function (paramIndex, decorator) {
    return function (target, key) { decorator(target, key, paramIndex); }
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.RoomsService = void 0;
const common_1 = require("@nestjs/common");
const ioredis_1 = require("ioredis");
const uuid_1 = require("uuid");
let RoomsService = class RoomsService {
    constructor(redis) {
        this.redis = redis;
    }
    async createRoom(config) {
        const roomId = (0, uuid_1.v4)();
        const expiry = config.expirySeconds || 7200;
        const roomKey = `room:${roomId}`;
        const payload = JSON.stringify({
            id: roomId,
            mode: config.mode || 'temporary',
            createdAt: Date.now(),
            expiryAt: Date.now() + (expiry * 1000),
        });
        await this.redis.set(roomKey, payload, 'EX', expiry);
        return roomId;
    }
    async getRoom(roomId) {
        const roomKey = `room:${roomId}`;
        const data = await this.redis.get(roomKey);
        return data ? JSON.parse(data) : null;
    }
    async addMessage(roomId, message, expiry) {
        const messageId = (0, uuid_1.v4)();
        const messageKey = `msg:${roomId}:${messageId}`;
        await this.redis.set(messageKey, JSON.stringify(message), 'EX', expiry);
    }
};
exports.RoomsService = RoomsService;
exports.RoomsService = RoomsService = __decorate([
    (0, common_1.Injectable)(),
    __param(0, (0, common_1.Inject)('REDIS_CLIENT')),
    __metadata("design:paramtypes", [ioredis_1.default])
], RoomsService);
//# sourceMappingURL=rooms.service.js.map