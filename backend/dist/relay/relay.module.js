"use strict";
var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.RelayModule = void 0;
const common_1 = require("@nestjs/common");
const relay_gateway_1 = require("./relay.gateway");
const rooms_module_1 = require("../rooms/rooms.module");
let RelayModule = class RelayModule {
};
exports.RelayModule = RelayModule;
exports.RelayModule = RelayModule = __decorate([
    (0, common_1.Module)({
        imports: [rooms_module_1.RoomsModule],
        providers: [relay_gateway_1.RelayGateway],
    })
], RelayModule);
//# sourceMappingURL=relay.module.js.map