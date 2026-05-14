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
var RelayGateway_1;
Object.defineProperty(exports, "__esModule", { value: true });
exports.RelayGateway = void 0;
const websockets_1 = require("@nestjs/websockets");
const socket_io_1 = require("socket.io");
const rooms_service_1 = require("../rooms/rooms.service");
const common_1 = require("@nestjs/common");
const ioredis_1 = require("ioredis");
let RelayGateway = RelayGateway_1 = class RelayGateway {
    constructor(roomsService, redisSub) {
        this.roomsService = roomsService;
        this.redisSub = redisSub;
        this.logger = new common_1.Logger(RelayGateway_1.name);
        this.setupKeyspaceNotifications();
    }
    handleConnection(client) {
        this.logger.log(`Client connected: ${client.id}`);
    }
    handleDisconnect(client) {
        this.logger.log(`Client disconnected: ${client.id}`);
    }
    async handleJoin(client, payload) {
        const room = await this.roomsService.getRoom(payload.roomId);
        if (!room) {
            client.emit('error', { message: 'Space not found or expired' });
            return;
        }
        client.join(payload.roomId);
        client.emit('space.joined', { roomId: payload.roomId });
        this.logger.log(`Client ${client.id} joined room ${payload.roomId}`);
    }
    async handleMessage(client, payload) {
        client.to(payload.roomId).emit('message.receive', payload);
        await this.roomsService.addMessage(payload.roomId, payload, payload.expiry || 300);
    }
    setupKeyspaceNotifications() {
        this.redisSub.subscribe('__keyevent@0__:expired');
        this.redisSub.on('message', (channel, message) => {
            if (message.startsWith('room:')) {
                const roomId = message.split(':')[1];
                this.server.to(roomId).emit('space.expired', { roomId });
                this.logger.log(`Space expired: ${roomId}`);
            }
        });
    }
};
exports.RelayGateway = RelayGateway;
__decorate([
    (0, websockets_1.WebSocketServer)(),
    __metadata("design:type", socket_io_1.Server)
], RelayGateway.prototype, "server", void 0);
__decorate([
    (0, websockets_1.SubscribeMessage)('space.join'),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [socket_io_1.Socket, Object]),
    __metadata("design:returntype", Promise)
], RelayGateway.prototype, "handleJoin", null);
__decorate([
    (0, websockets_1.SubscribeMessage)('message.send'),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [socket_io_1.Socket, Object]),
    __metadata("design:returntype", Promise)
], RelayGateway.prototype, "handleMessage", null);
exports.RelayGateway = RelayGateway = RelayGateway_1 = __decorate([
    (0, websockets_1.WebSocketGateway)({
        cors: {
            origin: '*',
        },
    }),
    __param(1, (0, common_1.Inject)('REDIS_SUBSCRIBER')),
    __metadata("design:paramtypes", [rooms_service_1.RoomsService,
        ioredis_1.default])
], RelayGateway);
//# sourceMappingURL=relay.gateway.js.map