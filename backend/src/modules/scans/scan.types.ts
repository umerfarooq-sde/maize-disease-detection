import type {
  ModelVersion,
  Scan,
  ScanPrediction,
  ScanUpload,
} from '../../generated/prisma/client.js';
import { AppError, type ErrorCode } from '../../errors/app-error.js';

export const scanLimits = {
  bytes: 5 * 1024 * 1024,
  pixels: 16_000_000,
  cleanupDelayMs: 15 * 60_000,
  inferenceLeaseMs: 2 * 60_000,
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
export type StoredPrediction = ScanPrediction & {
  modelVersion: Pick<ModelVersion, 'version' | 'preprocessingVersion'>;
};
export type ScanRecord = Scan & { predictions: StoredPrediction[] };
export type UploadRecord = ScanUpload & { scan: ScanRecord | null };
export interface ScanInput {
  userId: string | null;
  image: ValidatedImage;
  stored: StoredImage;
}

export const inferenceFailureCodes = [
  'INFERENCE_UNAVAILABLE',
  'INFERENCE_TIMEOUT',
  'INFERENCE_FAILED',
  'INFERENCE_INVALID_RESPONSE',
  'INFERENCE_PERSISTENCE_FAILED',
  'INFERENCE_INTERRUPTED',
  'INVALID_IMAGE',
] as const satisfies readonly ErrorCode[];

export function scanResponse(scan: ScanRecord) {
  const prediction = scan.status === 'COMPLETED' ? scan.predictions[0] : undefined;
  const code = inferenceFailureCodes.find((item) => item === scan.errorCode) ?? 'INFERENCE_FAILED';
  return {
    id: scan.id,
    status: scan.status,
    createdAt: scan.createdAt.toISOString(),
    finishedAt: scan.finishedAt?.toISOString() ?? null,
    prediction: prediction
      ? {
          predictedClass: prediction.predictedClass,
          confidence: prediction.confidence,
          probabilities: prediction.probabilities,
          modelVersion: prediction.modelVersion.version,
          preprocessingVersion: prediction.modelVersion.preprocessingVersion,
          predictionStatus: prediction.predictionStatus,
          uncertaintyReason: prediction.uncertaintyReason,
          confidenceThreshold: prediction.confidenceThreshold,
          inferenceDurationMs: prediction.inferenceDurationMs,
          inferredAt: prediction.inferredAt?.toISOString() ?? null,
        }
      : null,
    analysisError: scan.status === 'FAILED' ? { code, message: new AppError(code).message } : null,
    image: {
      url: scan.imageUrl,
      mimeType: scan.imageMimeType,
      bytes: scan.imageBytes,
      uploadedAt: scan.uploadedAt.toISOString(),
    },
  };
}
