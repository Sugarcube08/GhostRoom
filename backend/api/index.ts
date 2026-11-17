import "reflect-metadata";
import { NestFactory } from "@nestjs/core";
import { AppModule } from "../src/app.module";
import { ValidationPipe } from "@nestjs/common";
import { AllExceptionsFilter } from "../src/all-exceptions.filter";
import { ExpressAdapter } from "@nestjs/platform-express";
import express, { Express, Request, Response } from "express";

const server: Express = express();
let bootstrapPromise: Promise<void> | null = null;

async function bootstrap(): Promise<void> {
  if (!bootstrapPromise) {
    bootstrapPromise = (async () => {
      const app = await NestFactory.create(AppModule, new ExpressAdapter(server), {
        logger: ["error", "warn", "log"],
      });
      app.useGlobalFilters(new AllExceptionsFilter());
      app.useGlobalPipes(
        new ValidationPipe({
          whitelist: true,
          forbidNonWhitelisted: true,
          transform: true,
        }),
      );
      app.enableCors({
        origin: "*",
        methods: "GET,HEAD,PUT,PATCH,POST,DELETE,OPTIONS",
        credentials: true,
      });
      await app.init();
    })().catch((err) => {
      bootstrapPromise = null;
      throw err;
    });
  }
  return bootstrapPromise;
}

export default async function handler(req: Request, res: Response) {
  // Normalize rewrites: if Vercel routes /.* to /api, strip /api prefix so Nest routes match
  if (req.url) {
    if (req.url === "/api") {
      req.url = "/";
    } else if (req.url.startsWith("/api/")) {
      req.url = req.url.substring(4);
    }
  }

  try {
    await bootstrap();
    return server(req, res);
  } catch (err: any) {
    console.error("Vercel Serverless Invocation Fatal Error:", err);
    if (!res.headersSent) {
      res.status(500).json({
        statusCode: 500,
        error: "FUNCTION_INVOCATION_FAILED",
        message: err.message || "Relayer serverless initialization failed",
        timestamp: new Date().toISOString(),
      });
    }
  }
}
