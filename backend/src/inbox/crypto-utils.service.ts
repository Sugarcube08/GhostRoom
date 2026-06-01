import { Injectable } from "@nestjs/common";
import * as nacl from "tweetnacl";
import base58 from "bs58";
import { blake2b } from "blakejs";

@Injectable()
export class CryptoUtils {
  /**
   * Derives a Public ID from an Ed25519 Public Key.
   * Matches the client's logic: Base58(Blake2b(pk, outLen=20))
   */
  derivePublicId(publicKey: Uint8Array | string): string {
    const pkBuffer =
      typeof publicKey === "string"
        ? Buffer.from(publicKey, "base64")
        : Buffer.from(publicKey);

    // Blake2b 160-bit (20 bytes)
    const hash = blake2b(pkBuffer, undefined, 20);

    return base58.encode(hash);
  }

  /**
   * Verifies an Ed25519 signature.
   */
  verifySignature(
    message: string,
    signature: string,
    publicKey: string,
  ): boolean {
    try {
      const msgBuffer = Buffer.from(message);
      const sigBuffer = Buffer.from(signature, "base64");
      const pkBuffer = Buffer.from(publicKey, "base64");

      return nacl.sign.detached.verify(msgBuffer, sigBuffer, pkBuffer);
    } catch {
      return false;
    }
  }
}
