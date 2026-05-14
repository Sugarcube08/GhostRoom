"use strict";
var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.RedisModule = void 0;
const common_1 = require("@nestjs/common");
const config_1 = require("@nestjs/config");
const ioredis_1 = require("ioredis");
let RedisModule = class RedisModule {
};
exports.RedisModule = RedisModule;
exports.RedisModule = RedisModule = __decorate([
    (0, common_1.Global)(),
    (0, common_1.Module)({
        providers: [
            {
                provide: 'REDIS_CLIENT',
                useFactory: (configService) => {
                    const url = configService.get('REDIS_URL', 'redis://localhost:6379');
                    return new ioredis_1.default(url, {
                        maxRetriesPerRequest: null,
                        retryStrategy: (times) => Math.min(times * 50, 2000),
                    });
                },
                inject: [config_1.ConfigService],
            },
            {
                provide: 'REDIS_SUBSCRIBER',
                useFactory: (configService) => {
                    const url = configService.get('REDIS_URL', 'redis://localhost:6379');
                    return new ioredis_1.default(url, {
                        maxRetriesPerRequest: null,
                        retryStrategy: (times) => Math.min(times * 50, 2000),
                    });
                },
                inject: [config_1.ConfigService],
            },
        ],
        exports: ['REDIS_CLIENT', 'REDIS_SUBSCRIBER'],
    })
], RedisModule);
//# sourceMappingURL=redis.module.js.map