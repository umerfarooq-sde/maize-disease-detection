import { z } from 'zod';
import { knowledgeSearchSchema } from './knowledge.types.js';

export const diseaseListRequest = z.strictObject({
  body: z.undefined(),
  params: z.strictObject({}),
  query: z.strictObject({}),
});
export const diseaseDetailRequest = z.strictObject({
  body: z.undefined(),
  params: z.strictObject({
    slug: z
      .string()
      .min(1)
      .max(120)
      .regex(/^[a-z0-9]+(?:-[a-z0-9]+)*$/),
  }),
  query: z.strictObject({}),
});
export const knowledgeSearchRequest = z.strictObject({
  body: knowledgeSearchSchema,
  params: z.strictObject({}),
  query: z.strictObject({}),
});
