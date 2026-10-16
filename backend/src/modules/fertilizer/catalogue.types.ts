import { createHash } from 'node:crypto';
import { z } from 'zod';
import { fertilizerProductInputSchema } from './fertilizer.validators.js';
import { fertilizerSourceSchema } from './fertilizer.types.js';
import { managementText } from '../admin/management.types.js';
export const productInformation = z.strictObject({
  type: managementText(160).nullable(),
  growthStages: z.array(managementText(160)).max(12),
  suitableConditions: z.array(managementText(400)).max(12),
  applicationRateText: managementText(1000).nullable(),
  source: fertilizerSourceSchema,
  reviewNote: managementText(2000).min(20),
  approved: z.literal(true),
});
export const productWrite = z
  .strictObject({
    product: fertilizerProductInputSchema,
    information: productInformation,
    status: z.enum(['DRAFT', 'ACTIVE', 'INACTIVE']),
    expectedRevision: z
      .string()
      .regex(/^[a-f0-9]{64}$/)
      .optional(),
  })
  .refine((input) => input.product.sourceReference === input.information.source.url);
export type ProductWrite = z.infer<typeof productWrite>;
export const productStatus = z.strictObject({
  status: z.enum(['ACTIVE', 'INACTIVE']),
  expectedRevision: z.string().regex(/^[a-f0-9]{64}$/),
});
export function productRevision(
  row: { id: string; updatedAt: Date; status: string },
  metadataVersion: number,
) {
  return createHash('sha256')
    .update(JSON.stringify([row.id, row.updatedAt.toISOString(), row.status, metadataVersion]))
    .digest('hex');
}
