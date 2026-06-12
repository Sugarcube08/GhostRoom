import { Injectable, Logger, OnModuleInit } from "@nestjs/common";
import { ConfigService } from "@nestjs/config";
import { App, initializeApp, getApps, getApp, cert } from "firebase-admin/app";
import { getMessaging, Message } from "firebase-admin/messaging";

@Injectable()
export class FirebaseService implements OnModuleInit {
  private readonly logger = new Logger(FirebaseService.name);
  private firebaseApp: App | null = null;
  private credentialSource: "service_account_json" | "env_vars" | "none" = "none";
  private projectId = "unknown";
  private fcmEnabled = false;

  constructor(private readonly configService: ConfigService) {}

  async onModuleInit() {
    this.fcmEnabled = this.configService.get<string>("FCM_ENABLED") === "true";
    const serviceAccountJson = this.configService.get<string>("FCM_SERVICE_ACCOUNT");
    const envProjectId = this.configService.get<string>("FIREBASE_PROJECT_ID");
    const envClientEmail = this.configService.get<string>("FIREBASE_CLIENT_EMAIL");
    const envPrivateKey = this.configService.get<string>("FIREBASE_PRIVATE_KEY");

    this.logger.log("FCM_CONFIG_AUDIT_START");
    this.logger.log(`FCM_SERVICE_ACCOUNT_PRESENT=${!!serviceAccountJson}`);
    this.logger.log(`FIREBASE_PROJECT_ID_PRESENT=${!!envProjectId}`);
    this.logger.log(`FIREBASE_CLIENT_EMAIL_PRESENT=${!!envClientEmail}`);
    this.logger.log(`FIREBASE_PRIVATE_KEY_PRESENT=${!!envPrivateKey}`);

    if (serviceAccountJson) {
      this.credentialSource = "service_account_json";
    } else if (envProjectId && envClientEmail && envPrivateKey) {
      this.credentialSource = "env_vars";
    }

    if (this.fcmEnabled) {
      if (this.credentialSource === "none") {
        this.logger.error("FCM_ADMIN_INITIALIZATION_FAILED error=\"Firebase Admin credentials missing.\"");
        throw new Error("Firebase Admin credentials missing.");
      }

      try {
        if (getApps().length === 0) {
          if (this.credentialSource === "service_account_json") {
            const sa = JSON.parse(serviceAccountJson!);
            this.projectId = sa.project_id || envProjectId || "unknown";
            this.firebaseApp = initializeApp({
              credential: cert(sa),
              projectId: this.projectId,
            });
          } else {
            this.projectId = envProjectId!;
            const cleanedPrivateKey = envPrivateKey!.replace(/\\n/g, "\n");
            this.firebaseApp = initializeApp({
              credential: cert({
                projectId: this.projectId,
                clientEmail: envClientEmail,
                privateKey: cleanedPrivateKey,
              }),
              projectId: this.projectId,
            });
          }
        } else {
          this.firebaseApp = getApp();
          this.projectId = envProjectId || (this.firebaseApp.options as any)?.projectId || "unknown";
        }
        this.logger.log("FCM_ADMIN_INITIALIZED");
      } catch (err: any) {
        this.logger.error(`FCM_ADMIN_INITIALIZATION_FAILED error="${err.message}"`);
        throw err;
      }
    } else {
      this.logger.log("FCM is disabled in configuration.");
    }
  }

  getApp(): App | null {
    return this.firebaseApp;
  }

  getFcmEnabled(): boolean {
    return this.fcmEnabled;
  }

  getCredentialSource(): "service_account_json" | "env_vars" | "none" {
    return this.credentialSource;
  }

  getProjectId(): string {
    return this.projectId;
  }

  async sendWakeup(fcmToken: string, messageId: string): Promise<string | null> {
    if (!this.fcmEnabled || !this.firebaseApp) {
      this.logger.warn("FCM is disabled or Firebase Admin SDK not initialized.");
      return null;
    }

    const message: Message = {
      token: fcmToken,
      data: {
        event: "sync_required",
        message_id: messageId,
      },
      android: {
        priority: "high",
      },
      apns: {
        headers: {
          "apns-priority": "10",
        },
        payload: {
          aps: {
            contentAvailable: true,
          },
        },
      },
    };

    return await getMessaging(this.firebaseApp).send(message);
  }
}
