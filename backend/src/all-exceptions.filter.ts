import {
  ExceptionFilter,
  Catch,
  ArgumentsHost,
  HttpException,
  HttpStatus,
  Logger,
} from "@nestjs/common";

@Catch()
export class AllExceptionsFilter implements ExceptionFilter {
  private readonly logger = new Logger("AllExceptionsFilter");

  catch(exception: unknown, host: ArgumentsHost) {
    const ctx = host.switchToHttp();
    const response = ctx.getResponse();
    const request = ctx.getRequest();

    // Only handle HTTP requests (not websockets directly)
    if (!request || !response || typeof response.status !== "function") {
      this.logger.error(`Non-HTTP exception occurred: ${exception}`);
      if (exception instanceof Error) {
        this.logger.error(exception.stack);
      }
      return;
    }

    const status =
      exception instanceof HttpException
        ? exception.getStatus()
        : HttpStatus.INTERNAL_SERVER_ERROR;

    const message =
      exception instanceof Error
        ? exception.message
        : "Internal server error";

    const stack =
      exception instanceof Error
        ? exception.stack
        : "";

    this.logger.error(
      `GHOST_LOG: BACKEND_CRASH: status=${status} path=${request.url} method=${request.method} error="${message}"`,
    );
    if (stack) {
      this.logger.error(stack);
    }

    response.status(status).json({
      statusCode: status,
      timestamp: new Date().toISOString(),
      path: request.url,
      message: status === HttpStatus.INTERNAL_SERVER_ERROR ? "Internal server error" : message,
    });
  }
}
