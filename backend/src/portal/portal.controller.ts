import { Controller, Get, Req, Res, Param, Query } from "@nestjs/common";
import { Request, Response } from "express";
import * as fs from "fs";
import * as path from "path";

interface PlatformAssetInfo {
  name: string;
  format: string;
  filename: string;
  url: string;
  sha256: string;
  size_bytes: number;
}

interface VersionManifest {
  version: string;
  build_number?: number;
  release_date?: string;
  release_url?: string;
  changelog?: string;
  platforms: Record<string, PlatformAssetInfo>;
}

@Controller()
export class PortalController {
  private getVersionManifest(): VersionManifest {
    const candidates = [
      path.resolve(__dirname, "../../../version.json"),
      path.resolve(__dirname, "../../version.json"),
      path.resolve(process.cwd(), "version.json"),
      path.resolve(process.cwd(), "release/version.json"),
    ];

    for (const p of candidates) {
      try {
        if (fs.existsSync(p)) {
          const raw = fs.readFileSync(p, "utf-8");
          return JSON.parse(raw);
        }
      } catch (_) {}
    }

    // High-fidelity fallback if filesystem read is blocked in serverless
    return {
      version: "2.5.0",
      build_number: 6,
      release_date: new Date().toISOString(),
      release_url: "https://github.com/Sugarcube08/GhostRoom/releases/tag/v2.5.0",
      changelog:
        "GhostRoom v2.5.0: Zero-knowledge P2P store-and-forward relay, automated multi-platform updates with SHA-256 integrity verification, and portable .ghostkey identity vault.",
      platforms: {
        android: {
          name: "Android Package (APK)",
          format: "apk",
          filename: "ghostroom-android.apk",
          url: "https://github.com/Sugarcube08/GhostRoom/releases/download/v2.5.0/ghostroom-android.apk",
          sha256: "9e24fa89a56ec97e3546dda01d74c4d9fcfe78f9b1e7c7e6d04de700ac33ffb1",
          size_bytes: 82175926,
        },
        linux: {
          name: "Linux Universal AppImage",
          format: "appimage",
          filename: "ghostroom-linux-x86_64.AppImage",
          url: "https://github.com/Sugarcube08/GhostRoom/releases/download/v2.5.0/ghostroom-linux-x86_64.AppImage",
          sha256: "78a5596278b3c3a64354f93ff15170fa81ef89a4d23f44b27fce16388c252179",
          size_bytes: 12354752,
        },
        linux_deb: {
          name: "Debian / Ubuntu (.deb)",
          format: "deb",
          filename: "ghostroom-linux.deb",
          url: "https://github.com/Sugarcube08/GhostRoom/releases/download/v2.5.0/ghostroom-linux.deb",
          sha256: "eaaac911f169d988dd10549c9d0a93a640a73265c94251fc855ae100d2de1e64",
          size_bytes: 9817314,
        },
        linux_rpm: {
          name: "Fedora / RHEL / openSUSE (.rpm)",
          format: "rpm",
          filename: "ghostroom-2.5.0-2.x86_64.rpm",
          url: "https://github.com/Sugarcube08/GhostRoom/releases/download/v2.5.0/ghostroom-2.5.0-2.x86_64.rpm",
          sha256: "68d68159f5081f1df03cdc531ce7c48d3ea6f9834afea122b15fd47a1125484a",
          size_bytes: 9836152,
        },
        linux_tar: {
          name: "Linux Standalone Bundle (.tar.gz)",
          format: "tar.gz",
          filename: "ghostroom-linux-x86_64.tar.gz",
          url: "https://github.com/Sugarcube08/GhostRoom/releases/download/v2.5.0/ghostroom-linux-x86_64.tar.gz",
          sha256: "9667f6c83c98463e083abd9412df81c1650b90524d75ef6025ff44f5741b1c0b",
          size_bytes: 12102039,
        },
        web: {
          name: "Web Release Archive",
          format: "zip",
          filename: "ghostroom-web.zip",
          url: "https://github.com/Sugarcube08/GhostRoom/releases/download/v2.5.0/ghostroom-web.zip",
          sha256: "42e063968998cc71c116b9d9f8b18fc799c90438fdff8fc1c53285239cdfaf4d",
          size_bytes: 14779862,
        },
      },
    };
  }

  private brandSvgMark(): string {
    return `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512" width="48" height="48">
      <path fill="#7C5CFF" fill-rule="evenodd" d="M 256 72 C 335.53 72 400 136.47 400 216 L 400 380 C 400 412 376 436 352 436 C 328 436 316 404 304 404 C 292 404 280 436 256 436 C 232 436 220 404 208 404 C 196 404 184 436 160 436 C 136 436 112 412 112 380 L 112 216 C 112 136.47 176.47 72 256 72 Z M 196 176 A 20 20 0 0 0 176 196 L 176 228 A 20 20 0 0 0 216 228 L 216 196 A 20 20 0 0 0 196 176 Z M 316 176 A 20 20 0 0 0 296 196 L 296 228 A 20 20 0 0 0 336 228 L 336 196 A 20 20 0 0 0 316 176 Z M 256 264 A 28 28 0 0 0 233.6 300.8 L 240 348 A 16 16 0 0 0 272 348 L 278.4 300.8 A 28 28 0 0 0 256 264 Z"/>
    </svg>`;
  }

  private renderBaseStyles(): string {
    return `
      :root {
        --bg-void: #090A0F;
        --bg-slate: #12141D;
        --bg-slate-2: #1A1D2B;
        --border-line: #1F2333;
        --text-mist: #F4F6FA;
        --text-sub: #9BA3B8;
        --text-muted: #525A70;
        --accent-violet: #7C5CFF;
        --accent-violet-hover: #9175FF;
        --success-emerald: #3DDC97;
      }
      * { box-sizing: border-box; margin: 0; padding: 0; }
      body {
        background-color: var(--bg-void);
        color: var(--text-mist);
        font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Oxygen, Ubuntu, Cantarell, sans-serif;
        line-height: 1.6;
        min-height: 100vh;
        display: flex;
        flex-direction: column;
        -webkit-font-smoothing: antialiased;
      }
      a { color: inherit; text-decoration: none; }
      .mono {
        font-family: "JetBrains Mono", "Roboto Mono", "Courier New", monospace;
      }
      .navbar {
        display: flex;
        align-items: center;
        justify-content: space-between;
        padding: 20px 32px;
        border-bottom: 1px solid var(--border-line);
        background: rgba(9, 10, 15, 0.85);
        backdrop-filter: blur(12px);
        position: sticky;
        top: 0;
        z-index: 100;
      }
      .brand-lockup {
        display: flex;
        align-items: center;
        gap: 14px;
      }
      .brand-title {
        font-size: 19px;
        font-weight: 700;
        letter-spacing: 2px;
      }
      .nav-links {
        display: flex;
        align-items: center;
        gap: 24px;
      }
      .nav-link {
        color: var(--text-sub);
        font-size: 14px;
        font-weight: 500;
        transition: color 0.2s;
      }
      .nav-link:hover { color: var(--text-mist); }
      .btn-primary {
        background: var(--accent-violet);
        color: #FFFFFF;
        padding: 10px 20px;
        border-radius: 8px;
        font-size: 14px;
        font-weight: 600;
        letter-spacing: 0.5px;
        border: 1px solid transparent;
        transition: all 0.2s;
        display: inline-flex;
        align-items: center;
        gap: 8px;
      }
      .btn-primary:hover {
        background: var(--accent-violet-hover);
        transform: translateY(-1px);
      }
      .btn-secondary {
        background: var(--bg-slate);
        color: var(--text-mist);
        padding: 10px 20px;
        border-radius: 8px;
        font-size: 14px;
        font-weight: 600;
        border: 1px solid var(--border-line);
        transition: all 0.2s;
        display: inline-flex;
        align-items: center;
        gap: 8px;
      }
      .btn-secondary:hover {
        border-color: var(--accent-violet);
        background: var(--bg-slate-2);
      }
      .container {
        max-width: 1040px;
        margin: 0 auto;
        padding: 48px 24px;
        width: 100%;
      }
      .badge-pill {
        display: inline-flex;
        align-items: center;
        gap: 6px;
        padding: 4px 12px;
        border-radius: 100px;
        background: rgba(124, 92, 255, 0.12);
        border: 1px solid rgba(124, 92, 255, 0.35);
        color: var(--accent-violet);
        font-size: 12px;
        font-weight: 600;
        letter-spacing: 1px;
        margin-bottom: 20px;
      }
      .card {
        background: var(--bg-slate);
        border: 1px solid var(--border-line);
        border-radius: 12px;
        padding: 28px;
        transition: border-color 0.2s;
      }
      .card:hover {
        border-color: rgba(124, 92, 255, 0.4);
      }
      .grid-3 {
        display: grid;
        grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
        gap: 20px;
      }
      .grid-2 {
        display: grid;
        grid-template-columns: repeat(auto-fit, minmax(420px, 1fr));
        gap: 24px;
      }
      .footer {
        margin-top: auto;
        border-top: 1px solid var(--border-line);
        padding: 32px 24px;
        text-align: center;
        color: var(--text-muted);
        font-size: 13px;
      }
      @media (max-width: 640px) {
        .navbar { padding: 16px; }
        .grid-2 { grid-template-columns: 1fr; }
        .container { padding: 32px 16px; }
      }
    `;
  }

  @Get()
  getRoot(@Req() req: Request, @Res() res: Response, @Query("format") format?: string) {
    const acceptsHtml = req.accepts("html");
    if (format === "json" || (!acceptsHtml && req.accepts("json"))) {
      const manifest = this.getVersionManifest();
      return res.json({
        status: "online",
        service: "GhostRoom Relay",
        version: manifest.version,
        build_number: manifest.build_number,
        protocol: "store-and-forward",
        e2ee: "XChaCha20-Poly1305 + Ed25519",
        timestamp: new Date().toISOString(),
      });
    }

    const manifest = this.getVersionManifest();
    const html = `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>GhostRoom — Ephemeral Zero-Knowledge Communication</title>
  <meta name="description" content="Zero-knowledge, cryptographic ephemeral communication. No phone numbers, no emails, hardware-encrypted identity vault.">
  <link rel="icon" type="image/svg+xml" href="data:image/svg+xml;base64,${Buffer.from(this.brandSvgMark()).toString("base64")}">
  <style>${this.renderBaseStyles()}
    .hero {
      text-align: center;
      padding: 64px 0 52px;
    }
    .hero h1 {
      font-size: 48px;
      font-weight: 800;
      letter-spacing: -1px;
      line-height: 1.15;
      margin-bottom: 20px;
    }
    .hero p {
      font-size: 18px;
      color: var(--text-sub);
      max-width: 680px;
      margin: 0 auto 36px;
      line-height: 1.6;
    }
    .hero-actions {
      display: flex;
      justify-content: center;
      gap: 16px;
      flex-wrap: wrap;
    }
    .section-title {
      font-size: 24px;
      font-weight: 700;
      letter-spacing: -0.5px;
      margin-bottom: 24px;
      text-align: center;
    }
  </style>
</head>
<body>
  <nav class="navbar">
    <div class="brand-lockup">
      ${this.brandSvgMark()}
      <span class="brand-title">GHOSTROOM</span>
    </div>
    <div class="nav-links">
      <a href="#specs" class="nav-link">Architecture</a>
      <a href="/download" class="btn-primary">Download v${manifest.version}</a>
    </div>
  </nav>

  <main class="container">
    <div class="hero">
      <div class="badge-pill">ZERO-KNOWLEDGE • SOVEREIGN IDENTITIES</div>
      <h1>Architectural Privacy.<br>Zero Centralized State.</h1>
      <p>GhostRoom is a zero-metadata, end-to-end encrypted communication protocol. No phone numbers. No emails. Private keys never touch servers.</p>
      <div class="hero-actions">
        <a href="/download" class="btn-primary" style="padding: 14px 28px; font-size: 15px;">
          <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4M7 10l5 5 5-5M12 15V3"/></svg>
          Get GhostRoom v${manifest.version}
        </a>
        <a href="#specs" class="btn-secondary" style="padding: 14px 28px; font-size: 15px;">
          Cryptographic Specs
        </a>
      </div>
    </div>

    <div id="specs" style="margin-top: 48px;">
      <h2 class="section-title">Cryptographic Architecture</h2>
      <div class="grid-3">
        <div class="card">
          <div style="font-size: 24px; margin-bottom: 14px; color: var(--accent-violet);">🔒</div>
          <h3 style="font-size: 17px; margin-bottom: 8px;">Ed25519 & X25519</h3>
          <p style="color: var(--text-sub); font-size: 13px;">Curve25519 asymmetric cryptography. Ed25519 signatures authenticate envelopes while X25519 key-exchange protects peer messages.</p>
        </div>
        <div class="card">
          <div style="font-size: 24px; margin-bottom: 14px; color: var(--accent-violet);">⚡</div>
          <h3 style="font-size: 17px; margin-bottom: 8px;">Ephemeral Store-and-Forward</h3>
          <p style="color: var(--text-sub); font-size: 13px;">Relay instances store zero plaintext and zero metadata. Ephemeral ciphertext payloads auto-purge upon delivery confirmation or TTL.</p>
        </div>
        <div class="card">
          <div style="font-size: 24px; margin-bottom: 14px; color: var(--accent-violet);">🔑</div>
          <h3 style="font-size: 17px; margin-bottom: 8px;">Dual-Method Identity Vault</h3>
          <p style="color: var(--text-sub); font-size: 13px;">Restore identities using standard 24-word BIP-39 mnemonic passphrases or portable, hardware-encrypted .ghostkey files via Argon2id.</p>
        </div>
      </div>
    </div>

    <div style="margin-top: 56px;" class="card">
      <div style="display: flex; justify-content: space-between; align-items: center; flex-wrap: wrap; gap: 16px;">
        <div>
          <h3 style="font-size: 18px; margin-bottom: 4px;">Verified Cross-Platform Releases</h3>
          <p style="color: var(--text-sub); font-size: 13px;">Every binary derivative is compiled and strictly verified with SHA-256 cryptographic signatures.</p>
        </div>
        <a href="/download" class="btn-primary">View All Platforms</a>
      </div>
    </div>
  </main>

  <footer class="footer">
    <p>GhostRoom • Ephemeral Zero-Knowledge Communication • <span class="mono" style="color: var(--success-emerald);">● Relay Protocol Online</span></p>
  </footer>
</body>
</html>`;

    res.setHeader("Content-Type", "text/html; charset=utf-8");
    return res.send(html);
  }

  @Get("download")
  getDownloadPortal(@Req() req: Request, @Res() res: Response) {
    const manifest = this.getVersionManifest();
    const platforms = manifest.platforms;

    const html = `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Download GhostRoom — Release Distribution & SHA-256 Verification</title>
  <meta name="description" content="Download verified release binaries for GhostRoom across Android, Linux, and Web. Includes strict SHA-256 integrity checksums.">
  <link rel="icon" type="image/svg+xml" href="data:image/svg+xml;base64,${Buffer.from(this.brandSvgMark()).toString("base64")}">
  <style>${this.renderBaseStyles()}
    .release-header {
      padding: 32px 0;
      border-bottom: 1px solid var(--border-line);
      margin-bottom: 36px;
    }
    .platform-row {
      display: flex;
      justify-content: space-between;
      align-items: center;
      padding: 20px;
      border-bottom: 1px solid var(--border-line);
      flex-wrap: wrap;
      gap: 16px;
    }
    .platform-row:last-child { border-bottom: none; }
    .checksum-box {
      background: var(--bg-void);
      border: 1px solid var(--border-line);
      padding: 8px 12px;
      border-radius: 6px;
      font-size: 11px;
      color: var(--text-sub);
      display: flex;
      align-items: center;
      justify-content: space-between;
      gap: 12px;
      margin-top: 6px;
      word-break: break-all;
    }
    .copy-btn {
      background: none;
      border: 1px solid var(--border-line);
      color: var(--text-sub);
      padding: 4px 8px;
      border-radius: 4px;
      cursor: pointer;
      font-size: 10px;
      text-transform: uppercase;
      transition: all 0.2s;
    }
    .copy-btn:hover {
      color: var(--text-mist);
      border-color: var(--accent-violet);
    }
  </style>
</head>
<body>
  <nav class="navbar">
    <a href="/" class="brand-lockup">
      ${this.brandSvgMark()}
      <span class="brand-title">GHOSTROOM</span>
    </a>
    <div class="nav-links">
      <a href="/" class="nav-link">Overview</a>
      <a href="${manifest.release_url || "https://github.com/Sugarcube08/GhostRoom"}" target="_blank" class="nav-link">GitHub Release</a>
    </div>
  </nav>

  <main class="container">
    <div class="release-header">
      <div class="badge-pill">LATEST RELEASE • v${manifest.version}</div>
      <h1 style="font-size: 36px; font-weight: 800; margin-bottom: 8px;">Release Distribution</h1>
      <p style="color: var(--text-sub); font-size: 15px;">Cryptographically verified binaries. Compare local checksums against the signatures below prior to installation.</p>
    </div>

    <div class="card" style="padding: 0; overflow: hidden; margin-bottom: 36px;">
      <!-- Android -->
      <div class="platform-row">
        <div>
          <div style="display: flex; align-items: center; gap: 8px; margin-bottom: 4px;">
            <span style="font-weight: 700; font-size: 16px;">Android Package (.apk)</span>
            <span style="font-size: 11px; color: var(--text-muted);">${(platforms.android?.size_bytes ? (platforms.android.size_bytes / (1024 * 1024)).toFixed(1) + " MB" : "")}</span>
          </div>
          <p style="font-size: 12px; color: var(--text-sub);">Compatible with Android 8.0+ (ARM64, ARMv7, x86_64).</p>
          ${platforms.android?.sha256 ? `<div class="checksum-box"><span class="mono">${platforms.android.sha256}</span><button class="copy-btn" onclick="navigator.clipboard.writeText('${platforms.android.sha256}')">Copy</button></div>` : ""}
        </div>
        <a href="${platforms.android?.url || "#"}" class="btn-primary">Download APK</a>
      </div>

      <!-- Linux AppImage -->
      <div class="platform-row">
        <div>
          <div style="display: flex; align-items: center; gap: 8px; margin-bottom: 4px;">
            <span style="font-weight: 700; font-size: 16px;">Linux Universal (.AppImage)</span>
            <span style="font-size: 11px; color: var(--text-muted);">${(platforms.linux?.size_bytes ? (platforms.linux.size_bytes / (1024 * 1024)).toFixed(1) + " MB" : "")}</span>
          </div>
          <p style="font-size: 12px; color: var(--text-sub);">Standalone executable for all x86_64 Linux distributions (Ubuntu, Fedora, Arch, Debian).</p>
          ${platforms.linux?.sha256 ? `<div class="checksum-box"><span class="mono">${platforms.linux.sha256}</span><button class="copy-btn" onclick="navigator.clipboard.writeText('${platforms.linux.sha256}')">Copy</button></div>` : ""}
        </div>
        <a href="${platforms.linux?.url || "#"}" class="btn-primary">Download AppImage</a>
      </div>

      <!-- Linux DEB -->
      <div class="platform-row">
        <div>
          <div style="display: flex; align-items: center; gap: 8px; margin-bottom: 4px;">
            <span style="font-weight: 700; font-size: 16px;">Debian / Ubuntu Package (.deb)</span>
            <span style="font-size: 11px; color: var(--text-muted);">${(platforms.linux_deb?.size_bytes ? (platforms.linux_deb.size_bytes / (1024 * 1024)).toFixed(1) + " MB" : "")}</span>
          </div>
          <p style="font-size: 12px; color: var(--text-sub);">Native Debian installation with desktop integration.</p>
          ${platforms.linux_deb?.sha256 ? `<div class="checksum-box"><span class="mono">${platforms.linux_deb.sha256}</span><button class="copy-btn" onclick="navigator.clipboard.writeText('${platforms.linux_deb.sha256}')">Copy</button></div>` : ""}
        </div>
        <a href="${platforms.linux_deb?.url || "#"}" class="btn-secondary">Download .deb</a>
      </div>

      <!-- Linux RPM -->
      <div class="platform-row">
        <div>
          <div style="display: flex; align-items: center; gap: 8px; margin-bottom: 4px;">
            <span style="font-weight: 700; font-size: 16px;">Fedora / RHEL / openSUSE (.rpm)</span>
            <span style="font-size: 11px; color: var(--text-muted);">${(platforms.linux_rpm?.size_bytes ? (platforms.linux_rpm.size_bytes / (1024 * 1024)).toFixed(1) + " MB" : "")}</span>
          </div>
          <p style="font-size: 12px; color: var(--text-sub);">RedHat package manager binary format.</p>
          ${platforms.linux_rpm?.sha256 ? `<div class="checksum-box"><span class="mono">${platforms.linux_rpm.sha256}</span><button class="copy-btn" onclick="navigator.clipboard.writeText('${platforms.linux_rpm.sha256}')">Copy</button></div>` : ""}
        </div>
        <a href="${platforms.linux_rpm?.url || "#"}" class="btn-secondary">Download .rpm</a>
      </div>

      <!-- Linux Tarball -->
      <div class="platform-row">
        <div>
          <div style="display: flex; align-items: center; gap: 8px; margin-bottom: 4px;">
            <span style="font-weight: 700; font-size: 16px;">Linux Portable Archive (.tar.gz)</span>
            <span style="font-size: 11px; color: var(--text-muted);">${(platforms.linux_tar?.size_bytes ? (platforms.linux_tar.size_bytes / (1024 * 1024)).toFixed(1) + " MB" : "")}</span>
          </div>
          <p style="font-size: 12px; color: var(--text-sub);">Unpack and run without root permissions.</p>
          ${platforms.linux_tar?.sha256 ? `<div class="checksum-box"><span class="mono">${platforms.linux_tar.sha256}</span><button class="copy-btn" onclick="navigator.clipboard.writeText('${platforms.linux_tar.sha256}')">Copy</button></div>` : ""}
        </div>
        <a href="${platforms.linux_tar?.url || "#"}" class="btn-secondary">Download .tar.gz</a>
      </div>

      <!-- Web Bundle -->
      <div class="platform-row">
        <div>
          <div style="display: flex; align-items: center; gap: 8px; margin-bottom: 4px;">
            <span style="font-weight: 700; font-size: 16px;">Web Release Archive (.zip)</span>
            <span style="font-size: 11px; color: var(--text-muted);">${(platforms.web?.size_bytes ? (platforms.web.size_bytes / (1024 * 1024)).toFixed(1) + " MB" : "")}</span>
          </div>
          <p style="font-size: 12px; color: var(--text-sub);">Deploy to any static hosting or local web server.</p>
          ${platforms.web?.sha256 ? `<div class="checksum-box"><span class="mono">${platforms.web.sha256}</span><button class="copy-btn" onclick="navigator.clipboard.writeText('${platforms.web.sha256}')">Copy</button></div>` : ""}
        </div>
        <a href="${platforms.web?.url || "#"}" class="btn-secondary">Download .zip</a>
      </div>
    </div>

    <!-- Installation Instructions -->
    <h2 style="font-size: 20px; font-weight: 700; margin-bottom: 16px;">Installation & Verification Guide</h2>
    <div class="grid-2">
      <div class="card">
        <h3 style="font-size: 15px; margin-bottom: 8px; color: var(--text-mist);">Android Sideloading</h3>
        <p style="font-size: 12px; color: var(--text-sub); margin-bottom: 12px;">Android prevents sideloading by default. To install GhostRoom APK:</p>
        <ol style="font-size: 12px; color: var(--text-sub); padding-left: 20px; line-height: 1.8;">
          <li>Download <span class="mono" style="color: var(--text-mist);">ghostroom-android.apk</span> to your device.</li>
          <li>When prompted, tap <strong>Settings</strong> and enable <strong>Allow from this source</strong> for your browser.</li>
          <li>Open the APK file and select <strong>Install</strong>.</li>
        </ol>
      </div>

      <div class="card">
        <h3 style="font-size: 15px; margin-bottom: 8px; color: var(--text-mist);">Linux Execution</h3>
        <p style="font-size: 12px; color: var(--text-sub); margin-bottom: 12px;">Make the AppImage executable via terminal or file manager:</p>
        <pre class="mono" style="background: var(--bg-void); border: 1px solid var(--border-line); padding: 12px; border-radius: 6px; font-size: 12px; color: var(--accent-violet);">chmod +x ghostroom-linux-x86_64.AppImage
./ghostroom-linux-x86_64.AppImage</pre>
        <p style="font-size: 11px; color: var(--text-muted); margin-top: 8px;">Or install the Debian package via: <span class="mono">sudo dpkg -i ghostroom-linux.deb</span></p>
      </div>
    </div>
  </main>

  <footer class="footer">
    <p>GhostRoom • Ephemeral Zero-Knowledge Communication • All checksums generated with SHA-256</p>
  </footer>
</body>
</html>`;

    res.setHeader("Content-Type", "text/html; charset=utf-8");
    return res.send(html);
  }

  @Get("connect/:publicId")
  getConnectRedirect(@Param("publicId") publicId: string, @Res() res: Response) {
    return this.renderSmartRedirect(publicId, res);
  }

  @Get("u/:publicId")
  getShortConnectRedirect(@Param("publicId") publicId: string, @Res() res: Response) {
    return this.renderSmartRedirect(publicId, res);
  }

  private renderSmartRedirect(publicId: string, res: Response) {
    const cleanId = (publicId || "").replace(/[^a-zA-Z0-9_-]/g, "");
    const appSchemeUrl = `ghostroom://connect/${cleanId}`;

    const html = `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Connect on GhostRoom — ${cleanId}</title>
  <meta name="description" content="Add contact on GhostRoom: ${cleanId}">
  <link rel="icon" type="image/svg+xml" href="data:image/svg+xml;base64,${Buffer.from(this.brandSvgMark()).toString("base64")}">
  <style>${this.renderBaseStyles()}
    .redirect-card {
      max-width: 460px;
      margin: 64px auto;
      text-align: center;
      padding: 36px 28px;
    }
  </style>
</head>
<body>
  <main class="container">
    <div class="card redirect-card">
      <div style="margin-bottom: 20px;">${this.brandSvgMark()}</div>
      <div class="badge-pill">CONTACT INVITATION</div>
      <h1 style="font-size: 24px; font-weight: 700; margin-bottom: 10px;">Connecting to Peer</h1>
      <p style="color: var(--text-sub); font-size: 13px; margin-bottom: 20px;">Attempting to launch GhostRoom to verify cryptographic identity and add contact.</p>

      <div style="background: var(--bg-void); border: 1px solid var(--border-line); padding: 12px; border-radius: 8px; margin-bottom: 24px;">
        <span style="font-size: 11px; color: var(--text-muted); display: block; margin-bottom: 4px;">PUBLIC IDENTITY ID</span>
        <span class="mono" style="font-size: 13px; color: var(--accent-violet); font-weight: 700; word-break: break-all;">${cleanId}</span>
      </div>

      <div id="fallbackPrompt" style="display: none; animation: fadeIn 0.3s ease-in;">
        <p style="color: var(--text-sub); font-size: 13px; margin-bottom: 16px;">App not opening automatically? Install GhostRoom or open manually.</p>
        <div style="display: flex; flex-direction: column; gap: 10px;">
          <a href="${appSchemeUrl}" class="btn-primary" style="justify-content: center;">Open in GhostRoom App</a>
          <a href="/download" class="btn-secondary" style="justify-content: center;">Download GhostRoom Client</a>
        </div>
      </div>
    </div>
  </main>

  <script>
    const deepLink = "${appSchemeUrl}";
    // Immediately attempt to trigger custom scheme
    window.location.href = deepLink;

    // 1500ms visibility/timeout fallback
    let redirected = false;
    setTimeout(() => {
      if (!document.hidden && !redirected) {
        document.getElementById('fallbackPrompt').style.display = 'block';
      }
    }, 1500);

    // If page visibility changes, the user switched to the native app
    document.addEventListener("visibilitychange", () => {
      if (document.hidden) {
        redirected = true;
      }
    });
  </script>
</body>
</html>`;

    res.setHeader("Content-Type", "text/html; charset=utf-8");
    return res.send(html);
  }

  @Get(".well-known/assetlinks.json")
  getAssetLinks(@Res() res: Response) {
    const data = [
      {
        relation: ["delegate_permission/common.handle_all_urls"],
        target: {
          namespace: "android_app",
          package_name: "com.ghostroom.app",
          sha256_cert_fingerprints: [
            "E2:73:C6:08:44:0B:4D:2E:DE:3B:84:8A:23:45:90:38:62:3B:DF:C5:39:7A:B4:C9:F4:79:B0:1B:77:80:79:30",
          ],
        },
      },
    ];
    res.setHeader("Content-Type", "application/json");
    return res.json(data);
  }

  @Get(".well-known/apple-app-site-association")
  getAppleAppSiteAssociation(@Res() res: Response) {
    const data = {
      applinks: {
        apps: [],
        details: [
          {
            appID: "TEAMID.com.ghostroom.app",
            paths: ["/connect/*", "/u/*"],
          },
        ],
      },
    };
    res.setHeader("Content-Type", "application/json");
    return res.json(data);
  }
}
