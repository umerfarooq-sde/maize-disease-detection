import { z } from 'zod';
import { scanRequest } from '../scans/scan.validation.js';
import { askSchema } from './generation.types.js';

export const askRequest = z.strictObject({
  body: askSchema,
  params: z.strictObject({}),
  query: z.strictObject({}),
});
export const explanationRequest = z.strictObject({
  body: z.strictObject({}),
  params: z.strictObject({ scanId: z.uuid() }),
  query: z.strictObject({}),
  key: scanRequest.shape.key.optional(),
});
