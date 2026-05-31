import { Test, TestingModule } from '@nestjs/testing';
import { MediaService } from './media.service';
import { ConfigService } from '@nestjs/config';
import { getSignedUrl } from '@aws-sdk/s3-request-presigner';
import { describe, expect, it, jest, beforeEach } from '@jest/globals';

jest.mock('@aws-sdk/s3-request-presigner');
jest.mock('@aws-sdk/client-s3');

describe('MediaService', () => {
  let service: MediaService;
  let mockRedis: any;

  beforeEach(async () => {
    mockRedis = {
      hset: jest.fn(),
      expire: jest.fn(),
      hgetall: jest.fn(),
      del: jest.fn(),
      exists: jest.fn(),
    };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        MediaService,
        {
          provide: ConfigService,
          useValue: {
            get: jest.fn().mockImplementation((key) => {
              if (key === 'R2_ACCOUNT_ID') return 'test-account';
              return null;
            }),
          },
        },
        {
          provide: 'REDIS_CLIENT',
          useValue: mockRedis,
        },
      ],
    }).compile();

    service = module.get<MediaService>(MediaService);
  });

  it('should be defined', () => {
    expect(service).toBeDefined();
  });

  describe('generateUploadUrl', () => {
    it('should return a signed URL and store metadata', async () => {
      (getSignedUrl as any).mockResolvedValue('http://signed-put-url');
      
      const result = await service.generateUploadUrl('alice', 1024, 'image/jpeg');
      
      expect(result.mediaId).toBeDefined();
      expect(result.uploadUrl).toBe('http://signed-put-url');
      expect(mockRedis.hset).toHaveBeenCalledWith(
        expect.stringContaining('media:'),
        expect.objectContaining({
          owner: 'alice',
          state: 'UPLOADING',
        }),
      );
    });
  });
});
