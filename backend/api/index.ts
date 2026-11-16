import { NestFactory } from "@nestjs/core";
import { AppModule } from "../src/app.module";
import { ValidationPipe } from "@nestjs/common";
import { AllExceptionsFilter } from "../src/all-exceptions.filter";
import { ExpressAdapter } from "@nestjs/platform-express";
import express, { Express } from "express";

const server: Express = express();
let isReady = false;

async function bootstrap() {
  if (!isReady) {
    const app = await NestFactory.create(AppModule, new ExpressAdapter(server));
    app.useGlobalFilters(new AllExceptionsFilter());
    app.useGlobalPipes(
      new ValidationPipe({
        whitelist: true,
        forbidNonWhitelisted: true,
        transform: true,
      }),
    );
    app.enableCors();
    await app.init();
    isReady = true;
  }
}

export default async function handler(req: any, res: any) {
  await bootstrap();
  return server(req, res);
}
