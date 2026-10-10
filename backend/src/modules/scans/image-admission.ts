import type { ImageMime } from './scan.types.js';

// Admission only: matches shared preprocessing 1.0.0 without model transforms.
export const minimumImageSide = 16;
const pngEnd = Buffer.from([0, 0, 0, 0, 73, 69, 78, 68, 174, 66, 96, 130]);

export function checkImageContainer(bytes: Buffer, mimeType: ImageMime): void {
  if (
    (mimeType === 'image/jpeg' && !bytes.subarray(-2).equals(Buffer.from([0xff, 0xd9]))) ||
    (mimeType === 'image/png' && !bytes.subarray(-pngEnd.length).equals(pngEnd)) ||
    (mimeType === 'image/webp' && bytes.readUInt32LE(4) + 8 !== bytes.length)
  ) {
    throw new Error('Invalid image container');
  }
  if (mimeType === 'image/png') {
    // libvips may decode only the first APNG frame without reporting pages.
    let hasAnimationControl = false;
    let hasFrameControl = false;
    for (let offset = 8; offset <= bytes.length - 12; ) {
      const length = bytes.readUInt32BE(offset);
      if (length > bytes.length - offset - 12) throw new Error('Invalid image container');
      const type = bytes.toString('ascii', offset + 4, offset + 8);
      if (type === 'acTL') {
        hasAnimationControl = true;
        if (length !== 8 || bytes.readUInt32BE(offset + 8) !== 1) throw new Error('Animated image');
      }
      if (type === 'fcTL') hasFrameControl = true;
      // A separate default frame plus one animated frame is still two images.
      if (type === 'IDAT' && hasAnimationControl && !hasFrameControl)
        throw new Error('Animated image');
      offset += length + 12;
    }
  }
}

export function checkImageOrientation(
  exif: Buffer | undefined,
  orientation: number | undefined,
): void {
  if (
    orientation !== undefined &&
    (!Number.isInteger(orientation) || orientation < 1 || orientation > 8)
  ) {
    throw new Error('Invalid image orientation');
  }
  if (!exif) return;
  // libvips can omit an invalid raw orientation from metadata.orientation.
  // Inspect only the bounded IFD0 integer tag; decoding/EXIF rotation stays in Python.
  const start = exif.subarray(0, 6).equals(Buffer.from('Exif\0\0')) ? 6 : 0;
  const tiff = exif.subarray(start);
  const order = tiff.toString('ascii', 0, 2);
  if (tiff.length < 8 || !['II', 'MM'].includes(order)) return;
  const read16 = (offset: number) =>
    order === 'II' ? tiff.readUInt16LE(offset) : tiff.readUInt16BE(offset);
  const read32 = (offset: number) =>
    order === 'II' ? tiff.readUInt32LE(offset) : tiff.readUInt32BE(offset);
  if (read16(2) !== 42) return;
  const directory = read32(4);
  if (directory > tiff.length - 2) return;
  const entries = read16(directory);
  for (let index = 0; index < entries; index++) {
    const entry = directory + 2 + index * 12;
    if (entry > tiff.length - 12) return;
    if (read16(entry) !== 274) continue;
    const type = read16(entry + 2);
    const count = read32(entry + 4);
    if (count !== 1 || ![1, 3, 4].includes(type)) throw new Error('Invalid image orientation');
    const value = type === 1 ? tiff[entry + 8] : type === 3 ? read16(entry + 8) : read32(entry + 8);
    if (value === undefined || value < 1 || value > 8) throw new Error('Invalid image orientation');
  }
}
