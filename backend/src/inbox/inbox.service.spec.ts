import { Test, TestingModule } from '@nestjs/testing';
import { InboxService } from './inbox.service';
import { getRepositoryToken } from '@nestjs/typeorm';
import { MessageEntity } from './entities/message.entity';
import { DeliveryEntity } from './entities/delivery.entity';
import { describe, expect, it, jest, beforeEach } from '@jest/globals';

describe('InboxService', () => {
  let service: InboxService;
  let mockRedis: any;
  let mockMessageRepo: any;
  let mockDeliveryRepo: any;

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
      zrangebyscore: (jest.fn() as any).mockResolvedValue([]),
      mget: (jest.fn() as any).mockResolvedValue([]),
      zrem: (jest.fn() as any).mockResolvedValue(0),
      setex: (jest.fn() as any).mockResolvedValue('OK'),
      get: (jest.fn() as any).mockResolvedValue(null),
      del: (jest.fn() as any).mockResolvedValue(1),
    };

    mockMessageRepo = {
      create: jest.fn().mockImplementation((entity) => entity),
      save: (jest.fn() as any).mockResolvedValue({}),
      find: (jest.fn() as any).mockResolvedValue([]),
      delete: (jest.fn() as any).mockResolvedValue({}),
    };

    mockDeliveryRepo = {
      create: jest.fn().mockImplementation((entity) => entity),
      save: (jest.fn() as any).mockResolvedValue({}),
      update: (jest.fn() as any).mockResolvedValue({}),
    };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        InboxService,
        {
          provide: 'REDIS_CLIENT',
          useValue: mockRedis,
        },
        {
          provide: getRepositoryToken(MessageEntity),
          useValue: mockMessageRepo,
        },
        {
          provide: getRepositoryToken(DeliveryEntity),
          useValue: mockDeliveryRepo,
        },
      ],
    }).compile();

    service = module.get<InboxService>(InboxService);
  });

  it('should be defined', () => {
    expect(service).toBeDefined();
  });

  describe('queueMessage', () => {
    it('should store message in Postgres and Redis', async () => {
      const publicId = 'test-id';
      const payload = { id: 'msg-id', n: 'nonce', c: 'ciphertext' };
      
      const envelope = await service.queueMessage(publicId, payload);
      
      expect(envelope).toBeDefined();
      expect(mockMessageRepo.create).toHaveBeenCalled();
      expect(mockMessageRepo.save).toHaveBeenCalled();
      expect(mockDeliveryRepo.save).toHaveBeenCalled();
      expect(mockRedis.pipeline).toHaveBeenCalled();
    });
  });

  describe('fetchMessages', () => {
    it('should return messages from Postgres', async () => {
      mockMessageRepo.find = (jest.fn() as any).mockResolvedValue([{ envelope: { id: 'msg-id', c: 'ciphertext' } }]);
      
      const messages = await service.fetchMessages('test-id');
      expect(messages).toHaveLength(1);
      expect(messages[0].id).toBe('msg-id');
    });
  });

  describe('acknowledgeMessage', () => {
    it('should remove from Postgres and Redis', async () => {
      await service.acknowledgeMessage('test-id', 'msg-id');
      
      expect(mockMessageRepo.delete).toHaveBeenCalledWith({ id: 'msg-id', recipient_id: 'test-id' });
      expect(mockDeliveryRepo.update).toHaveBeenCalledWith({ message_id: 'msg-id' }, { status: 'ACKNOWLEDGED' });
      const pipeline = mockRedis.pipeline();
      expect(pipeline.zrem).toHaveBeenCalledWith('inbox:test-id', 'msg-id');
      expect(pipeline.del).toHaveBeenCalledWith('msg:msg-id');
    });
  });
});
