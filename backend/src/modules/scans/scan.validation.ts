import { extname } from 'node:path';
import sharp from 'sharp';
import { z } from 'zod';
import { AppError } from '../../errors/app-error.js';
import { checkImageContainer, checkImageOrientation, minimumImageSide } from './image-admission.js';
import { type ImageMime, scanLimits, type ValidatedImage } from './scan.types.js';

export const scanRequest = z.object({
  params: z.strictObject({}),
  query: z.strictObject({}),
  key: z.uuid().regex(/^[a-f0-9]{8}-[a-f0-9]{4}-4[a-f0-9]{3}-[89ab][a-f0-9]{3}-[a-f0-9]{12}$/),
});

function detectMime(bytes: Buffer): ImageMime | null {
  if (bytes.subarray(0, 3).equals(Buffer.from([0xff, 0xd8, 0xff]))) return 'image/jpeg';
  if (bytes.subarray(0, 8).equals(Buffer.from([137, 80, 78, 71, 13, 10, 26, 10])))
    return 'image/png';
  if (bytes.toString('ascii', 0, 4) === 'RIFF' && bytes.toString('ascii', 8, 12) === 'WEBP')
    return 'image/webp';
  return null;
}

export async function validateImage(
  file: Express.Multer.File | undefined,
): Promise<ValidatedImage> {
  if (!file || file.buffer.length === 0) throw new AppError('VALIDATION_ERROR');
  if (file.buffer.length > scanLimits.bytes) throw new AppError('PAYLOAD_TOO_LARGE');
  const mimeType = detectMime(file.buffer);
  const allowedExtensions: Record<ImageMime, string[]> = {
    'image/jpeg': ['.jpg', '.jpeg'],
    'image/png': ['.png'],
    'image/webp': ['.webp'],
  };
  if (
    !mimeType ||
    file.mimetype !== mimeType ||
    !allowedExtensions[mimeType].includes(extname(file.originalname).toLowerCase())
  ) {
    throw new AppError('UNSUPPORTED_MEDIA_TYPE');
  }
  try {
    checkImageContainer(file.buffer, mimeType);
    // Security decoding only. Original bytes remain unchanged; no ML preprocessing.
    const decoder = sharp(file.buffer, {
      limitInputPixels: scanLimits.pixels,
      failOn: 'warning',
      animated: true,
    });
    const metadata = await decoder.metadata();
    if (
      !metadata.width ||
      !metadata.height ||
      Math.min(metadata.width, metadata.height) < minimumImageSide ||
      (metadata.pages ?? 1) !== 1 ||
      metadata.width * metadata.height > scanLimits.pixels
    ) {
      throw new Error('Invalid image dimensions or animation');
    }
    checkImageOrientation(metadata.exif, metadata.orientation);
    // metadata() alone accepts some truncated files: require complete pixel decoding.
    await decoder.timeout({ seconds: 5 }).raw().toBuffer();
    return {
      bytes: file.buffer,
      mimeType,
      width: metadata.width,
      height: metadata.height,
      orientation: metadata.orientation ?? 1,
    };
  } catch {
    throw new AppError('INVALID_IMAGE');
  }
}
