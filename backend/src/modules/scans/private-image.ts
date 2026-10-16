import sharp from 'sharp';
import type { Environment } from '../../config/environment.js';
import { AppError } from '../../errors/app-error.js';
import { checkImageContainer } from './image-admission.js';
import { privateStorageImage } from './image-privacy.js';
import { type ImageMime, scanLimits } from './scan.types.js';

export interface ImageLocation {
  url: string;
  publicId: string;
  purpose: 'scans' | 'profiles' | 'references';
}
export interface PrivateImage {
  bytes: Buffer;
  mimeType: ImageMime;
}
export type PrivateImageReader = (location: ImageLocation) => Promise<PrivateImage>;

export function createPrivateImageReader(
  environment: Pick<Environment, 'CLOUDINARY_CLOUD_NAME'>,
  transport: typeof fetch = fetch,
): PrivateImageReader {
  let active = 0;
  return async (location) => {
    if (active >= 2) throw new AppError('RATE_LIMITED');
    const namespace = `maizedoctor/${location.purpose}/`;
    if (
      !location.publicId.startsWith(namespace) ||
      !/^[a-f0-9-]{36}$/.test(location.publicId.slice(namespace.length))
    )
      throw new AppError('NOT_FOUND');
    const url = new URL(location.url);
    const root = `/${environment.CLOUDINARY_CLOUD_NAME}/image/authenticated/`;
    const path = url.pathname.slice(root.length);
    const match = /^s--[A-Za-z0-9_-]{8,64}--\/(?:v[0-9]+\/)?(.+)\.(jpg|png|webp)$/.exec(path);
    if (
      url.origin !== 'https://res.cloudinary.com' ||
      url.username ||
      url.password ||
      (url.search &&
        !(
          url.searchParams.size === 1 &&
          /^[A-Za-z0-9_-]{1,128}$/.test(url.searchParams.get('_a') ?? '')
        )) ||
      url.hash ||
      !url.pathname.startsWith(root) ||
      match?.[1] !== location.publicId
    )
      throw new AppError('NOT_FOUND');
    // Older SDK-generated URLs contain an unsigned analytics tag. It is not
    // required for authenticated delivery and is never forwarded upstream.
    url.search = '';
    active++;
    const controller = new AbortController();
    let rejectDeadline: ((error: AppError) => void) | undefined;
    const deadline = new Promise<never>((_resolve, reject) => {
      rejectDeadline = reject;
    });
    const timer = setTimeout(() => {
      controller.abort();
      rejectDeadline?.(new AppError('UPLOAD_UNAVAILABLE'));
    }, 10000);
    let reader: ReadableStreamDefaultReader<Uint8Array> | undefined;
    try {
      const response = await Promise.race([
        transport(url, {
          redirect: 'manual',
          signal: controller.signal,
          headers: { 'Accept-Encoding': 'identity' },
        }),
        deadline,
      ]);
      const mime = response.headers.get('content-type')?.split(';')[0]?.trim();
      const maximum = 16 * 1024 * 1024;
      const length = response.headers.get('content-length');
      if (
        response.status !== 200 ||
        !response.body ||
        !['image/jpeg', 'image/png', 'image/webp'].includes(mime ?? '') ||
        ![null, 'identity'].includes(response.headers.get('content-encoding')) ||
        (length !== null && (!/^[0-9]{1,10}$/.test(length) || Number(length) > maximum))
      )
        throw new AppError('UPLOAD_UNAVAILABLE');
      reader = response.body.getReader();
      let size = 0;
      const parts: Uint8Array[] = [];
      while (true) {
        const part = await Promise.race([reader.read(), deadline]);
        if (part.done) break;
        size += part.value.length;
        if (size > maximum) throw new AppError('UPLOAD_UNAVAILABLE');
        parts.push(part.value);
      }
      const bytes = Buffer.concat(parts);
      checkImageContainer(bytes, mime as ImageMime);
      const metadata = await sharp(bytes, {
        limitInputPixels: scanLimits.pixels,
        failOn: 'warning',
      }).metadata();
      const formats = { jpeg: 'image/jpeg', png: 'image/png', webp: 'image/webp' } as const;
      if (
        !metadata.width ||
        !metadata.height ||
        (metadata.pages ?? 1) !== 1 ||
        Math.min(metadata.width, metadata.height) < 16 ||
        metadata.width * metadata.height > scanLimits.pixels ||
        !(metadata.format && metadata.format in formats) ||
        formats[metadata.format as keyof typeof formats] !== mime
      )
        throw new AppError('UPLOAD_UNAVAILABLE');
      // Also remove private metadata on delivery of legacy assets without changing
      // or deleting stored user data. No original Cloudinary URL reaches the caller.
      if (
        !metadata.exif &&
        !metadata.xmp &&
        !metadata.iptc &&
        !metadata.icc &&
        !metadata.orientation
      ) {
        await sharp(bytes, { limitInputPixels: scanLimits.pixels, failOn: 'warning' })
          .timeout({ seconds: 5 })
          .raw()
          .toBuffer();
        return { bytes, mimeType: mime as ImageMime };
      }
      const safe = await privateStorageImage({
        bytes,
        mimeType: mime as ImageMime,
        width: metadata.width,
        height: metadata.height,
        orientation: metadata.orientation ?? 1,
      });
      return { bytes: safe.bytes, mimeType: safe.mimeType };
    } catch {
      throw new AppError('UPLOAD_UNAVAILABLE');
    } finally {
      clearTimeout(timer);
      controller.abort();
      void reader?.cancel().catch(() => {});
      active--;
    }
  };
}
