/**
 * Web Crypto API implementation for Aether Sovereign Vault
 * 100% Offline, Native, Zero-Knowledge End-to-End Encryption
 * Algorithm: AES-256-GCM + PBKDF2 (100,000 rounds, SHA-256)
 */

function arrayBufferToHex(buffer: ArrayBuffer): string {
  const byteArray = new Uint8Array(buffer);
  let hex = '';
  for (let i = 0; i < byteArray.length; i++) {
    hex += byteArray[i].toString(16).padStart(2, '0');
  }
  return hex;
}

function hexToArrayBuffer(hex: string): Uint8Array {
  const typedArray = new Uint8Array(hex.length / 2);
  for (let i = 0; i < hex.length; i += 2) {
    typedArray[i / 2] = parseInt(hex.substring(i, i + 2), 16);
  }
  return typedArray;
}

/**
 * Compute SHA-256 cryptographic hash of string
 */
export async function sha256(input: string): Promise<string> {
  const encoder = new TextEncoder();
  const data = encoder.encode(input);
  const hashBuffer = await window.crypto.subtle.digest('SHA-256', data);
  return arrayBufferToHex(hashBuffer);
}

/**
 * Derive an AES-GCM 256-bit key from a user password and cryptographic salt using PBKDF2
 */
export async function deriveKey(password: string, salt: Uint8Array): Promise<CryptoKey> {
  const encoder = new TextEncoder();
  const keyMaterial = await window.crypto.subtle.importKey(
    'raw',
    encoder.encode(password),
    'PBKDF2',
    false,
    ['deriveKey']
  );

  return window.crypto.subtle.deriveKey(
    {
      name: 'PBKDF2',
      salt: salt,
      iterations: 100000,
      hash: 'SHA-256',
    },
    keyMaterial,
    { name: 'AES-GCM', length: 256 },
    false,
    ['encrypt', 'decrypt']
  );
}

/**
 * Encrypt plaintext using AES-GCM 256 with dynamic IV and Salt
 */
export async function encryptText(
  text: string,
  passphrase: string
): Promise<{ ciphertext: string; iv: string; salt: string; checksum: string }> {
  const salt = window.crypto.getRandomValues(new Uint8Array(16));
  const iv = window.crypto.getRandomValues(new Uint8Array(12));
  const key = await deriveKey(passphrase, salt);
  const encoder = new TextEncoder();
  const encodedData = encoder.encode(text);

  const encryptedBuffer = await window.crypto.subtle.encrypt(
    {
      name: 'AES-GCM',
      iv: iv,
    },
    key,
    encodedData
  );

  const checksum = await sha256(text);

  return {
    ciphertext: arrayBufferToHex(encryptedBuffer),
    iv: arrayBufferToHex(iv.buffer),
    salt: arrayBufferToHex(salt.buffer),
    checksum,
  };
}

/**
 * Decrypt AES-GCM 256 ciphertext
 */
export async function decryptText(
  ciphertextHex: string,
  ivHex: string,
  saltHex: string,
  passphrase: string
): Promise<string> {
  const salt = hexToArrayBuffer(saltHex);
  const iv = hexToArrayBuffer(ivHex);
  const key = await deriveKey(passphrase, salt);
  const cipherBuffer = hexToArrayBuffer(ciphertextHex);

  const decryptedBuffer = await window.crypto.subtle.decrypt(
    {
      name: 'AES-GCM',
      iv: iv,
    },
    key,
    cipherBuffer
  );

  const decoder = new TextDecoder();
  return decoder.decode(decryptedBuffer);
}

/**
 * Hash password with salt for vault master lock verification
 */
export async function createPasswordHash(password: string): Promise<{ hash: string; saltHex: string }> {
  const salt = window.crypto.getRandomValues(new Uint8Array(16));
  const saltHex = arrayBufferToHex(salt.buffer);
  const hash = await sha256(`${password}:${saltHex}`);
  return { hash, saltHex };
}

export async function verifyPassword(
  password: string,
  saltHex: string,
  expectedHash: string
): Promise<boolean> {
  const hash = await sha256(`${password}:${saltHex}`);
  return hash === expectedHash;
}
