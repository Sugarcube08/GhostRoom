import { Test, TestingModule } from '@nestjs/testing';
import { MediaService } from './media.service';
import { ConfigService } from '@nestjs/config';
import { getSignedUrl } from '@aws-sdk/s3-request-presigner';
import { getRepositoryToken } from '@nestjs/typeorm';
import { MediaEntity } from './entities/media.entity';
import { AuditService } from '../audit/audit.service';
import { describe, expect, it, jest, beforeEach } from '@jest/globals';

jest.mock('@aws-sdk/s3-request-presigner');
jest.mock('@aws-sdk/client-s3');

describe('MediaService', () => {
  let service: MediaService;
  let mockRedis: any;
  let mockMediaRepo: any;
  let mockAuditService: any;

  beforeEach(async () => {
    mockRedis = {
      pipeline: jest.fn().mockReturnValue({
        incrby: jest.fn().mockReturnThis(),
        incr: jest.fn().mockReturnThis(),
        expire: jest.fn().mockReturnThis(),
        exec: (jest.fn() as any).mockResolvedValue([]),
      }),
      get: (jest.fn() as any).mockResolvedValue(null),
    };

    mockMediaRepo = {
      create: jest.fn().mockImplementation((entity) => entity),
      save: (jest.fn() as any).mockResolvedValue({}),
      findOne: (jest.fn() as any).mockResolvedValue({ owner_id: 'alice', state: 'UPLOADING' }),
      delete: (jest.fn() as any).mockResolvedValue({}),
      find: (jest.fn() as any).mockResolvedValue([]),
    };

    mockAuditService = {
      log: (jest.fn() as any).mockResolvedValue(undefined),
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
        {
          provide: getRepositoryToken(MediaEntity),
          useValue: mockMediaRepo,
        },
        {
          provide: AuditService,
          useValue: mockAuditService,
        },
      ],
    }).compile();

    service = module.get<MediaService>(MediaService);
  });

  it('should be defined', () => {
    expect(service).toBeDefined();
  });

  describe('generateUploadUrl', () => {
    it('should return a signed URL and store metadata in Postgres', async () => {
      (getSignedUrl as any).mockResolvedValue('http://signed-put-url');
      
      const result = await service.generateUploadUrl('alice', 1024, 'image/jpeg', 'some-hash');
      
      expect(result.mediaId).toBeDefined();
      expect(result.uploadUrl).toBe('http://signed-put-url');
      expect(mockMediaRepo.create).toHaveBeenCalledWith(
        expect.objectContaining({
          owner_id: 'alice',
          state: 'UPLOADING',
        }),
      );
      expect(mockAuditService.log).toHaveBeenCalledWith('media_upload_requested', expect.any(Object));
    });
  });
});
