import { Controller, Post, Get, Param, Body, Headers, BadRequestException, ForbiddenException } from '@nestjs/common';
import { MediaService } from './media.service';

@Controller('media')
export class MediaController {
  constructor(private readonly mediaService: MediaService) {}

  @Post('upload-url')
  async getUploadUrl(
    @Body() body: { size: number; mime: string; hash: string },
    @Headers('x-public-id') publicId: string,
  ) {
    if (!publicId) {
      throw new BadRequestException('Missing x-public-id header');
    }
    if (!body.hash) {
      throw new BadRequestException('Missing content hash');
    }

    // Limit enforcement
    if (body.mime.startsWith('image/') && body.size > 10 * 1024 * 1024) {
      throw new BadRequestException('Image too large (Max 10MB)');
    }
    if (body.mime.startsWith('video/') && body.size > 30 * 1024 * 1024) {
      throw new BadRequestException('Video too large (Max 30MB)');
    }

    try {
      const result = await this.mediaService.generateUploadUrl(publicId, body.size, body.mime, body.hash);
      return result;
    } catch (e: any) {
      throw new BadRequestException(e.message);
    }
  }

  @Get('download-url/:id')
  async getDownloadUrl(@Param('id') mediaId: string) {
    try {
      return await this.mediaService.generateDownloadUrl(mediaId);
    } catch (e: any) {
      throw new BadRequestException(e.message);
    }
  }

  @Post('confirm/:id')
  async confirmUpload(
    @Param('id') mediaId: string,
    @Headers('x-public-id') publicId: string,
  ) {
    try {
      await this.mediaService.confirmUpload(publicId, mediaId);
      return { status: 'confirmed' };
    } catch (e: any) {
      if (e.message.startsWith('Forbidden')) throw new ForbiddenException(e.message);
      throw new BadRequestException(e.message);
    }
  }

  @Post('reference/:id')
  async referenceMedia(
    @Param('id') mediaId: string,
    @Headers('x-public-id') publicId: string,
  ) {
    try {
      await this.mediaService.referenceMedia(publicId, mediaId);
      return { status: 'referenced' };
    } catch (e: any) {
      if (e.message.startsWith('Forbidden')) throw new ForbiddenException(e.message);
      throw new BadRequestException(e.message);
    }
  }
}
