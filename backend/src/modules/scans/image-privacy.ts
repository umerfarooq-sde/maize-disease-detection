import sharp from 'sharp';
import { AppError } from '../../errors/app-error.js';
import { scanLimits, type ValidatedImage } from './scan.types.js';

// Storage/delivery only. Inference and idempotency always use the original input.
// Never call this from validation or the Node -> FastAPI client.
export async function privateStorageImage(image: ValidatedImage): Promise<ValidatedImage> {
  try {
    // Sharp strips EXIF/GPS/XMP/IPTC by default. Bake orientation into the display
    // pixels; do not retain user metadata/filenames or request an ML transform.
    const encoder = sharp(image.bytes, {
      limitInputPixels: scanLimits.pixels,
      failOn: 'warning',
    }).autoOrient();
    if (image.mimeType === 'image/jpeg') encoder.jpeg({ quality: 95, chromaSubsampling: '4:4:4' });
    else if (image.mimeType === 'image/webp') encoder.webp({ lossless: true });
    else encoder.png({ compressionLevel: 9 });
    const output = await encoder.timeout({ seconds: 5 }).toBuffer({ resolveWithObject: true });
    // Re-encoding can expand a highly compressed input. Bound the storage copy
    // independently of the unchanged 5 MiB encoded input admission contract.
    if (output.data.length > 16 * 1024 * 1024) throw new Error('Storage copy too large');
    return {
      ...image,
      bytes: output.data,
      width: output.info.width,
      height: output.info.height,
      orientation: 1,
    };
  } catch {
    throw new AppError('UPLOAD_FAILED');
  }
}
