import { RoomsService } from './rooms.service';
export declare class RoomsController {
    private readonly roomsService;
    constructor(roomsService: RoomsService);
    createRoom(config: {
        mode?: string;
        expirySeconds?: number;
    }): Promise<{
        roomId: string;
    }>;
}
