import Redis from 'ioredis';
export declare class RoomsService {
    private readonly redis;
    constructor(redis: Redis);
    createRoom(config: any): Promise<string>;
    getRoom(roomId: string): Promise<any>;
    addMessage(roomId: string, message: any, expiry: number): Promise<void>;
}
