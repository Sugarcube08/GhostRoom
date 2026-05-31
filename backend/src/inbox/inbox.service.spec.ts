import { Test, TestingModule } from '@nestjs/testing';
import { InboxService } from './inbox.service';
import { describe, expect, it, jest, beforeEach } from '@jest/globals';

describe('InboxService', () => {
  let service: InboxService;
  let mockRedis: any;

  beforeEach(async () => {
    mockRedis = {
      pipeline: jest.fn().mockReturnValue({
        setex: jest.fn().mockReturnThis(),
        zadd: jest.fn().mockReturnThis(),
        zremrangebyrank: jest.fn().mockReturnThis(),
        expire: jest.fn().mockReturnThis(),
        zrem: jest.fn().mockReturnThis(),
        del: jest.fn().mockReturnThis(),
        exec: (jest.fn() as any).mockResolvedValue([]),
      }),
      zrangebyscore: jest.fn(),
      mget: jest.fn(),
      zrem: jest.fn(),
      setex: jest.fn(),
      get: jest.fn(),
      del: jest.fn(),
    };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        InboxService,
        {
          provide: 'REDIS_CLIENT',
          useValue: mockRedis,
        },
      ],
    }).compile();

    service = module.get<InboxService>(InboxService);
  });

  it('should be defined', () => {
    expect(service).toBeDefined();
  });

  describe('queueMessage', () => {
    it('should store message and add to inbox zset', async () => {
      const publicId = 'test-id';
      const payload = { n: 'nonce', c: 'ciphertext' };
      
      const envelope = await service.queueMessage(publicId, payload);
      
      expect(envelope).toBeDefined();
      expect(envelope.v).toBe(2);
      expect(mockRedis.pipeline).toHaveBeenCalled();
      const pipeline = mockRedis.pipeline();
      expect(pipeline.setex).toHaveBeenCalledWith(
        expect.stringContaining('msg:'),
        expect.any(Number),
        expect.stringContaining('ciphertext'),
      );
      expect(pipeline.zadd).toHaveBeenCalledWith(
        `inbox:${publicId}`,
        expect.any(Number),
        envelope.id,
      );
    });
  });

  describe('fetchMessages', () => {
    it('should return empty array if no messages', async () => {
      mockRedis.zrangebyscore.mockResolvedValue([]);
      const messages = await service.fetchMessages('test-id');
      expect(messages).toEqual([]);
    });

    it('should fetch messages from store and cleanup missing ones', async () => {
      const publicId = 'test-id';
      mockRedis.zrangebyscore.mockResolvedValue(['id1', 'id2']);
      mockRedis.mget.mockResolvedValue([
        JSON.stringify({ id: 'id1', c: 'msg1' }),
        null, // Missing/expired
      ]);

      const messages = await service.fetchMessages(publicId);

      expect(messages).toHaveLength(1);
      expect(messages[0].id).toBe('id1');
      expect(mockRedis.zrem).toHaveBeenCalledWith(`inbox:${publicId}`, 'id2');
    });
  });

  describe('acknowledgeMessage', () => {
    it('should remove from zset and delete message store', async () => {
      await service.acknowledgeMessage('test-id', 'msg-id');
      const pipeline = mockRedis.pipeline();
      expect(pipeline.zrem).toHaveBeenCalledWith('inbox:test-id', 'msg-id');
      expect(pipeline.del).toHaveBeenCalledWith('msg:msg-id');
    });
  });
});
