// Synthetic QA bridge only: receives fixtures on stdin, never fetches remote URLs.
// Run from backend with `node --import tsx ../scripts/check-image-admission-contract.mjs`.
import { AppError } from '../backend/src/errors/app-error.ts';
import { validateImage } from '../backend/src/modules/scans/scan.validation.ts';

const chunks = [];
for await (const chunk of process.stdin) chunks.push(chunk);
const fixtures = JSON.parse(Buffer.concat(chunks).toString('utf8'));
const results = [];
for (const fixture of fixtures) {
  try {
    const bytes = Buffer.from(fixture.encoded, 'base64');
    const image = await validateImage({
      buffer: bytes,
      mimetype: fixture.media_type,
      originalname: fixture.filename,
    });
    results.push({ name: fixture.name, accepted: true, unchanged: image.bytes === bytes });
  } catch (error) {
    if (!(error instanceof AppError)) throw error;
    results.push({ name: fixture.name, accepted: false, error_code: error.code });
  }
}
process.stdout.write(JSON.stringify(results));
