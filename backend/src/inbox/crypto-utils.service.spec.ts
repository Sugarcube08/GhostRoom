import { Test, TestingModule } from "@nestjs/testing";
import { CryptoUtils } from "./crypto-utils.service";
import * as nacl from "tweetnacl";
import { describe, expect, it, beforeEach } from "@jest/globals";

describe("CryptoUtils", () => {
  let service: CryptoUtils;

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [CryptoUtils],
    }).compile();

    service = module.get<CryptoUtils>(CryptoUtils);
  });

  it("should be defined", () => {
    expect(service).toBeDefined();
  });

  it("should derive Public ID correctly", () => {
    // Generate a random keypair for testing
    const keypair = nacl.sign.keyPair();
    const publicId = service.derivePublicId(keypair.publicKey);

    expect(publicId).toBeDefined();
    expect(typeof publicId).toBe("string");
    // Base58 typically shorter than base64
    expect(publicId.length).toBeLessThan(44);
  });

  it("should verify valid signatures", () => {
    const keypair = nacl.sign.keyPair();
    const message = "test-message";
    const signature = Buffer.from(
      nacl.sign.detached(Buffer.from(message), keypair.secretKey),
    ).toString("base64");
    const publicKey = Buffer.from(keypair.publicKey).toString("base64");

    const isValid = service.verifySignature(message, signature, publicKey);
    expect(isValid).toBe(true);
  });

  it("should reject invalid signatures", () => {
    const keypair = nacl.sign.keyPair();
    const message = "test-message";
    const signature = Buffer.from(
      nacl.sign.detached(Buffer.from("wrong-message"), keypair.secretKey),
    ).toString("base64");
    const publicKey = Buffer.from(keypair.publicKey).toString("base64");

    const isValid = service.verifySignature(message, signature, publicKey);
    expect(isValid).toBe(false);
  });
});
