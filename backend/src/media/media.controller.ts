import { Controller, Post, Get, Param, Body, Headers, BadRequestException } from '@nestjs/common';
import { MediaService } from './media.service';

@Controller('media')
export class MediaController {
  constructor(private readonly mediaService: MediaService) {}

  @Post('upload-url')
  async getUploadUrl(
    @Body() body: { size: number; mime: string },
    @Headers('x-public-id') publicId: string,
  ) {
    if (!publicId) {
      throw new BadRequestException('Missing x-public-id header');
    }
    // Limit enforcement
    if (body.mime.startsWith('image/') && body.size > 10 * 1024 * 1024) {
      throw new BadRequestException('Image too large (Max 10MB)');
    }
    if (body.mime.startsWith('video/') && body.size > 30 * 1024 * 1024) {
      throw new BadRequestException('Video too large (Max 30MB)');
    }

    return await this.mediaService.generateUploadUrl(publicId, body.size, body.mime);
  }

  @Get('download-url/:id')
  async getDownloadUrl(@Param('id') mediaId: string) {
    return await this.mediaService.generateDownloadUrl(mediaId);
  }

  @Post('confirm/:id')
  async confirmUpload(@Param('id') mediaId: string) {
    await this.mediaService.updateState(mediaId, 'UPLOADED');
    return { status: 'confirmed' };
  }
}
