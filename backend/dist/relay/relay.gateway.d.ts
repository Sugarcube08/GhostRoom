import { OnGatewayConnection, OnGatewayDisconnect } from '@nestjs/websockets';
import { Server, Socket } from 'socket.io';
import { RoomsService } from '../rooms/rooms.service';
import Redis from 'ioredis';
export declare class RelayGateway implements OnGatewayConnection, OnGatewayDisconnect {
    private readonly roomsService;
    private readonly redisSub;
    private readonly logger;
    server: Server;
    constructor(roomsService: RoomsService, redisSub: Redis);
    handleConnection(client: Socket): void;
    handleDisconnect(client: Socket): void;
    handleJoin(client: Socket, payload: {
        roomId: string;
    }): Promise<void>;
    handleMessage(client: Socket, payload: {
        roomId: string;
        ciphertext: string;
        nonce: string;
        expiry: number;
    }): Promise<void>;
    private setupKeyspaceNotifications;
}
