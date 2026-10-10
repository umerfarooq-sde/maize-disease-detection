import assert from 'node:assert/strict';
import { test } from 'node:test';
import { crc32 } from 'node:zlib';
import sharp from 'sharp';
import { AppError } from '../../src/errors/app-error.js';
import { validateImage } from '../../src/modules/scans/scan.validation.js';
import { imageFile } from './helpers.js';

const invalidImage = (error: unknown) =>
  error instanceof AppError && error.code === 'INVALID_IMAGE';

for (const format of ['jpeg', 'png', 'webp'] as const) {
  test(`${format}: shared minimum side is inclusive and applies before ML inference`, async () => {
    const file = await imageFile(format);
    for (const [width, height] of [
      [16, 16],
      [16, 64],
      [64, 16],
    ] as const) {
      const buffer = await sharp({
        create: { width, height, channels: 3, background: '#765a36' },
      })
        .toFormat(format)
        .toBuffer();
      const actual = await validateImage({ ...file, buffer, size: buffer.length });
      assert.equal(actual.bytes, buffer);
      assert.equal(actual.width, width);
      assert.equal(actual.height, height);
    }
    for (const [width, height] of [
      [1, 1],
      [15, 32],
      [32, 15],
    ] as const) {
      const buffer = await sharp({
        create: { width, height, channels: 3, background: '#765a36' },
      })
        .toFormat(format)
        .toBuffer();
      await assert.rejects(validateImage({ ...file, buffer, size: buffer.length }), invalidImage);
    }
  });

  test(`${format}: trailing data and missing container end fail safely`, async () => {
    const file = await imageFile(format);
    await assert.rejects(
      validateImage({
        ...file,
        buffer: Buffer.concat([file.buffer, Buffer.from('trailing data')]),
      }),
      invalidImage,
    );
    await assert.rejects(
      validateImage({ ...file, buffer: file.buffer.subarray(0, -2) }),
      invalidImage,
    );
  });
}

test('WebP RIFF size must equal the unchanged encoded body length', async () => {
  const file = await imageFile('webp');
  for (const difference of [-2, 2]) {
    const buffer = Buffer.from(file.buffer);
    buffer.writeUInt32LE(buffer.readUInt32LE(4) + difference, 4);
    await assert.rejects(validateImage({ ...file, buffer }), invalidImage);
  }
});

test('PNG corruption is rejected even when the IEND marker remains intact', async () => {
  const file = await imageFile('png');
  const buffer = Buffer.from(file.buffer);
  const offset = buffer.indexOf(Buffer.from('IDAT')) + 5;
  buffer[offset] = buffer.readUInt8(offset) ^ 0xff;
  await assert.rejects(validateImage({ ...file, buffer }), invalidImage);
});

test('PNG multi-frame declarations are rejected even when the decoder omits page count', async () => {
  const file = await imageFile('png');
  const animation = Buffer.alloc(20);
  animation.writeUInt32BE(8, 0);
  animation.write('acTL', 4, 'ascii');
  animation.writeUInt32BE(2, 8);
  animation.writeUInt32BE(crc32(animation.subarray(4, 16)), 16);
  const insertion = file.buffer.indexOf(Buffer.from('IDAT')) - 4;
  assert.ok(insertion >= 8);
  const buffer = Buffer.concat([
    file.buffer.subarray(0, insertion),
    animation,
    file.buffer.subarray(insertion),
  ]);
  assert.equal((await sharp(buffer, { animated: true }).metadata()).pages ?? 1, 1);
  await assert.rejects(validateImage({ ...file, buffer }), invalidImage);
});

test('valid grayscale and alpha images retain original bytes without model transformations', async () => {
  const file = await imageFile('png');
  for (const channels of [1, 2, 4] as const) {
    const buffer = await sharp(Buffer.alloc(24 * 32 * channels, 120), {
      raw: { width: 24, height: 32, channels },
    })
      .png()
      .toBuffer();
    const actual = await validateImage({ ...file, buffer });
    assert.equal(actual.bytes, buffer);
    assert.equal(actual.width, 24);
    assert.equal(actual.height, 32);
  }
});

test('the shared invalid EXIF orientation is rejected before storage', async () => {
  const file = await imageFile('jpeg', 6);
  const buffer = Buffer.from(file.buffer);
  // sharp writes little-endian EXIF. Change the orientation SHORT from 6 to 9.
  const tag = buffer.indexOf(Buffer.from([0x12, 0x01, 0x03, 0x00, 0x01, 0x00, 0x00, 0x00]));
  assert.ok(tag >= 0);
  buffer.writeUInt16LE(9, tag + 8);
  await assert.rejects(validateImage({ ...file, buffer }), invalidImage);
});
