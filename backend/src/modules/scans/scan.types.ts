import type { Scan, ScanUpload } from '../../generated/prisma/client.js';

export const scanLimits = {
  bytes: 5 * 1024 * 1024,
  pixels: 16_000_000,
  cleanupDelayMs: 15 * 60_000,
} as const;
export type ImageMime = 'image/jpeg' | 'image/png' | 'image/webp';
export interface ValidatedImage {
  bytes: Buffer;
  mimeType: ImageMime;
  width: number;
  height: number;
  orientation: number;
}
export interface StoredImage {
  url: string;
  publicId: string;
  uploadedAt: Date;
}
export interface ImageStorage {
  readonly enabled: boolean;
  upload(image: ValidatedImage, publicId: string): Promise<StoredImage>;
  destroy(publicId: string): Promise<void>;
}
export type UploadRecord = ScanUpload & { scan: Scan | null };
export interface ScanInput {
  userId: string | null;
  image: ValidatedImage;
  stored: StoredImage;
}

export function scanResponse(scan: Scan) {
  return {
    id: scan.id,
    status: scan.status,
    createdAt: scan.createdAt.toISOString(),
    image: {
      url: scan.imageUrl,
      mimeType: scan.imageMimeType,
      bytes: scan.imageBytes,
      uploadedAt: scan.uploadedAt.toISOString(),
    },
  };
}
