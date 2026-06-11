# Firebase FCM Backend & Deployment Setup

This document outlines the configuration, deployment, and verification steps for enabling Firebase Cloud Messaging (FCM) push notification wakeups on the GhostRoom Backend.

---

## 1. How to Generate `service-account.json`

To enable Firebase Admin SDK initialization, you must generate credentials from the Firebase Console:

1. Go to the [Firebase Console](https://console.firebase.google.com/).
2. Select your GhostRoom project.
3. Click the **Gear icon (Project Settings)** in the top-left menu.
4. Navigate to the **Service accounts** tab.
5. Click **Generate new private key** at the bottom of the page.
6. A file named `your-project-id-firebase-adminsdk-xxxxx-xxxxxx.json` (referred to as `service-account.json`) will be downloaded.

Keep this file secure. It contains sensitive credentials that authorize root access to your Firebase services.

---

## 2. How to Configure Render

On Render (or similar hosting providers), you can configure FCM credentials using one of two methods:

### Method A: Individual Environment Variables (Recommended)
Add the following Environment Variables in the **Environment** tab of your Render service:

| Variable Name | Value |
| :--- | :--- |
| `FCM_ENABLED` | `true` |
| `FIREBASE_PROJECT_ID` | `ghostroom-fcm` *(your project ID)* |
| `FIREBASE_CLIENT_EMAIL` | `firebase-adminsdk-xxx@ghostroom-fcm.iam.gserviceaccount.com` |
| `FIREBASE_PRIVATE_KEY` | `-----BEGIN PRIVATE KEY-----\nMIIEvgIBADANBgkqhkiG9w0BAQEFAASCBKgwggSkAgEAAoIBAQC...` |

> [!IMPORTANT]
> The `FIREBASE_PRIVATE_KEY` value **must preserve newline characters** using literal `\n` notation. Ensure the entire key is wrapped in quotes or entered on a single line with `\n` replacing line breaks.

### Method B: Single JSON Environment Variable
Alternatively, pass the entire stringified contents of the downloaded `service-account.json`:

| Variable Name | Value |
| :--- | :--- |
| `FCM_ENABLED` | `true` |
| `FCM_SERVICE_ACCOUNT` | `{"type": "service_account", "project_id": "ghostroom-fcm", ...}` |

---

## 3. How to Rotate Credentials

To rotate Firebase Admin SDK credentials periodically or in the event of a leak:

1. Go to **Firebase Console** > **Project Settings** > **Service accounts**.
2. Click **Manage service account permissions** or open the linked Google Cloud Platform IAM console.
3. Select the service account used for the SDK and navigate to **Keys**.
4. Click **Add Key** > **Create new key** (JSON format) to generate the new credentials.
5. Update your hosting provider (e.g., Render) environment variables with the new values.
6. Trigger a redeploy/restart.
7. Once verified, delete the old key from the GCP console.

---

## 4. How to Verify FCM

### Startup Checks
Verify that the backend initializes properly. If `FCM_ENABLED=true` but credentials are missing, the server will crash at startup with a hard exception:
`Error: Firebase Admin credentials missing.`

### API Health Check
Once running, request the FCM health check endpoint:

`GET /health/fcm`

Expected response (e.g. for `service_account_json` configuration):
```json
{
  "initialized": true,
  "projectId": "ghostroom-fcm",
  "credentialSource": "service_account_json"
}
```

---

## 5. Expected Startup Logs

A healthy startup with FCM enabled should display logs in the following sequence:

```text
[Nest] LOG [FirebaseService] FCM_CONFIG_AUDIT_START
[Nest] LOG [FirebaseService] FCM_SERVICE_ACCOUNT_PRESENT=true
[Nest] LOG [FirebaseService] FIREBASE_PROJECT_ID_PRESENT=false
[Nest] LOG [FirebaseService] FIREBASE_CLIENT_EMAIL_PRESENT=false
[Nest] LOG [FirebaseService] FIREBASE_PRIVATE_KEY_PRESENT=false
[Nest] LOG [FirebaseService] FCM_ADMIN_INITIALIZED
```

---

## 6. Troubleshooting Guide

### Issue: Startup Crash with `Firebase Admin credentials missing.`
* **Cause**: `FCM_ENABLED` is set to `true`, but neither the `FCM_SERVICE_ACCOUNT` variable nor the three individual variables (`FIREBASE_PROJECT_ID`, `FIREBASE_CLIENT_EMAIL`, and `FIREBASE_PRIVATE_KEY`) are present.
* **Resolution**: Provide credentials in the environment configuration, or set `FCM_ENABLED=false` if push notifications are not required.

### Issue: `FCM_ADMIN_INITIALIZATION_FAILED error="..."` at Startup
* **Cause**: The credentials provided are malformed or invalid (e.g. `FCM_SERVICE_ACCOUNT` JSON is not parseable, or `FIREBASE_PRIVATE_KEY` has lost its newline format).
* **Resolution**: Verify that the JSON structure is correct. If using individual variables, confirm that private key newlines (`\n`) are preserved.

### Issue: Push delivered but app does not wake up when terminated/killed
* **Cause**: On some Android versions, data-only messages do not wake the app if it is force-stopped.
* **Resolution**: The backend now wraps FCM wakeups in a notification payload containing a title and body block. This guarantees that the operating system displays the notification UI and schedules the background handler isolate to execute background sync tasks.
