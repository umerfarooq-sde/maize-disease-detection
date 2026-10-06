import { v2 as cloudinary } from 'cloudinary';
import { z } from 'zod';
import type { Environment } from '../../config/environment.js';
import { AppError } from '../../errors/app-error.js';
import type { ImageStorage } from './scan.types.js';

const uploadResult = z.object({
  public_id: z.string(),
  resource_type: z.literal('image'),
  type: z.literal('authenticated'),
  format: z.enum(['jpg', 'png', 'webp']),
  width: z.number().int().positive(),
  height: z.number().int().positive(),
  bytes: z.number().int().positive(),
  version: z.number().int().positive(),
  created_at: z.iso.datetime(),
});
const projectAsset =
  /^maizedoctor\/scans\/[a-f0-9]{8}-[a-f0-9]{4}-4[a-f0-9]{3}-[89ab][a-f0-9]{3}-[a-f0-9]{12}$/;

export function createImageStorage(environment: Environment): ImageStorage {
  const options = {
    cloud_name: environment.CLOUDINARY_CLOUD_NAME,
    api_key: environment.CLOUDINARY_API_KEY,
    api_secret: environment.CLOUDINARY_API_SECRET,
    secure: true,
    timeout: 45_000,
  };
  const enabled = !!options.cloud_name && !!options.api_key && !!options.api_secret;
  function guard(publicId: string) {
    if (!enabled) throw new AppError('UPLOAD_UNAVAILABLE');
    if (!projectAsset.test(publicId)) throw new AppError('INTERNAL_SERVER_ERROR');
  }
  return {
    enabled,
    async upload(image, publicId) {
      guard(publicId);
      try {
        const raw = await new Promise<unknown>((resolve, reject) => {
          const stream = cloudinary.uploader.upload_stream(
            {
              ...options,
              public_id: publicId,
              resource_type: 'image',
              type: 'authenticated',
              overwrite: false,
              unique_filename: false,
              allowed_formats: ['jpg', 'png', 'webp'],
            },
            (error, result) => (error ? reject(error) : resolve(result)),
          );
          stream.on('error', reject);
          stream.end(image.bytes);
        });
        const result = uploadResult.parse(raw);
        const formats = { 'image/jpeg': 'jpg', 'image/png': 'png', 'image/webp': 'webp' } as const;
        // JPEG provider dimensions can reflect EXIF orientation even though the
        // stored original bytes are unchanged. Other formats may report raw size.
        const dimensionsMatch =
          (result.width === image.width && result.height === image.height) ||
          ([5, 6, 7, 8].includes(image.orientation) &&
            result.width === image.height &&
            result.height === image.width);
        if (
          result.public_id !== publicId ||
          !dimensionsMatch ||
          result.bytes !== image.bytes.length ||
          result.format !== formats[image.mimeType]
        )
          throw new Error('Unexpected stored image');
        // Authenticated assets reject unsigned delivery. The signed URL is a bearer
        // capability, not a Cloudinary credential; do not log or share it publicly.
        const url = cloudinary.url(publicId, {
          ...options,
          type: 'authenticated',
          resource_type: 'image',
          version: result.version,
          format: result.format,
          sign_url: true,
        });
        const parsed = new URL(url);
        if (
          parsed.protocol !== 'https:' ||
          parsed.hostname !== 'res.cloudinary.com' ||
          parsed.username ||
          parsed.password
        )
          throw new Error('Unexpected delivery URL');
        return { url, publicId, uploadedAt: new Date(result.created_at) };
      } catch {
        throw new AppError('UPLOAD_FAILED');
      }
    },
    async destroy(publicId) {
      guard(publicId);
      try {
        const result: unknown = await cloudinary.uploader.destroy(publicId, {
          ...options,
          resource_type: 'image',
          type: 'authenticated',
          invalidate: true,
        });
        const parsed = z.object({ result: z.enum(['ok', 'not found']) }).safeParse(result);
        if (!parsed.success) throw new Error('Deletion unconfirmed');
      } catch {
        throw new AppError('UPLOAD_FAILED');
      }
    },
  };
}
