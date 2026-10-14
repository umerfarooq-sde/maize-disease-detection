import { z } from 'zod';
import { Prisma } from '../../generated/prisma/client.js';
import {
  calculatorInputSchema,
  decimalWithin,
  fertilizerDecimalSchema,
  fertilizerProductSnapshotSchema,
  fertilizerSourceSchema,
} from './fertilizer.types.js';

const text = (maximum: number) =>
  z
    .string()
    .trim()
    .min(1)
    .max(maximum)
    .refine(
      (value) =>
        !Array.from(value).some((char) => {
          const code = char.codePointAt(0) ?? 0;
          return (code < 32 && code !== 9 && code !== 10) || code === 127;
        }),
    );
const percentage = z
  .string()
  .max(6)
  .regex(/^(?:0|[1-9]\d{0,2})(?:\.\d{1,2})?$/)
  .refine((value) => decimalWithin(value, '100', 2))
  .transform((value) => new Prisma.Decimal(value).toFixed(2));
const version = z.number().int().min(1).max(2147483647);
const identifier = z
  .string()
  .min(1)
  .max(120)
  .regex(/^[a-z0-9]+(?:-[a-z0-9]+)*$/);

export const fertilizerProductInputSchema = fertilizerProductSnapshotSchema.extend({
  nitrogenPercent: percentage,
  phosphorusPercent: percentage,
  potassiumPercent: percentage,
});
export type FertilizerProductInput = z.infer<typeof fertilizerProductInputSchema>;

export const fertilizerDraftInputSchema = z.strictObject({
  product: fertilizerProductInputSchema,
  rule: z.strictObject({
    ruleKey: identifier,
    version,
    title: text(160),
    rateKgPerHectare: fertilizerDecimalSchema,
    applicability: text(2000),
    assumptions: z.array(text(400)).min(1).max(8),
    source: fertilizerSourceSchema,
    reviewNote: text(2000).refine((value) => value.length >= 20),
  }),
  config: z.strictObject({
    version,
    quantityDecimalPlaces: z.number().int().min(0).max(6),
  }),
});
export type FertilizerDraftInput = z.infer<typeof fertilizerDraftInputSchema>;

const empty = z.strictObject({});
export const fertilizerListRequest = z.strictObject({
  body: z.undefined(),
  params: empty,
  query: empty,
});
export const fertilizerCalculateRequest = z.strictObject({
  body: calculatorInputSchema,
  params: empty,
  query: empty,
});
export const fertilizerDraftRequest = z.strictObject({
  body: fertilizerDraftInputSchema,
  params: empty,
  query: empty,
});
export const fertilizerStatusRequest = z.strictObject({
  body: z.strictObject({ status: z.enum(['ACTIVE', 'INACTIVE']) }),
  params: z.strictObject({ ruleId: z.uuid() }),
  query: empty,
});
