import { z } from 'zod';
import {
  calculatorAreaSchema,
  calculatorDecimalSchema,
  calculatorSourceSchema,
  calculatorText,
  calculatorVersionSchema,
} from '../calculators/calculator.contract.js';

export const YIELD_CONFIG_KEY = 'maize-area-yield' as const;
export const YIELD_ENGINE_VERSION = 'area-yield-v1' as const;
// A dimensional projection template; no agronomic formula/rate has been approved.
export const YIELD_FORMULA_VERSION = 'area-times-reviewed-yield-rate-v1' as const;
export const yieldInputSchema = z.strictObject({
  area: calculatorAreaSchema,
  areaUnit: z.enum(['HECTARE', 'ACRE']),
  outputUnit: z.enum(['KG', 'TONNE']),
  configId: z.uuid(),
  configVersion: calculatorVersionSchema,
});
export const yieldParametersSchema = z.strictObject({
  algorithm: z.literal('AREA_TIMES_REVIEWED_YIELD_RATE_V1'),
  engineVersion: z.literal(YIELD_ENGINE_VERSION),
  formulaVersion: z.literal(YIELD_FORMULA_VERSION),
  crop: z.literal('MAIZE'),
  title: calculatorText(160),
  expectedYieldKgPerHectare: calculatorDecimalSchema,
  applicability: calculatorText(2000),
  assumptions: z.array(calculatorText(400)).min(1).max(8),
  source: calculatorSourceSchema,
  quantityDecimalPlaces: z.number().int().min(0).max(6),
  roundingMode: z.literal('HALF_UP'),
  approval: z.strictObject({
    status: z.literal('PROJECT_APPROVED_SOURCE'),
    reviewedAt: z.iso.datetime(),
    reviewedBy: z.uuid(),
    note: calculatorText(2000).refine((value) => value.length >= 20),
  }),
});
export const yieldDraftSchema = z.strictObject({
  version: calculatorVersionSchema,
  title: calculatorText(160),
  expectedYieldKgPerHectare: calculatorDecimalSchema,
  applicability: calculatorText(2000),
  assumptions: z.array(calculatorText(400)).min(1).max(8),
  source: calculatorSourceSchema,
  quantityDecimalPlaces: z.number().int().min(0).max(6),
  reviewNote: calculatorText(2000).refine((value) => value.length >= 20),
});
const empty = z.strictObject({});
export const yieldListRequest = z.strictObject({
  body: z.undefined(),
  params: empty,
  query: empty,
});
export const yieldCalculateRequest = z.strictObject({
  body: yieldInputSchema,
  params: empty,
  query: empty,
});
export const yieldDraftRequest = z.strictObject({
  body: yieldDraftSchema,
  params: empty,
  query: empty,
});
export const yieldStatusRequest = z.strictObject({
  body: z.strictObject({ status: z.enum(['ACTIVE', 'INACTIVE']) }),
  params: z.strictObject({ configId: z.uuid() }),
  query: empty,
});
export type YieldInput = z.infer<typeof yieldInputSchema>;
export type YieldDraft = z.infer<typeof yieldDraftSchema>;
export type YieldParameters = z.infer<typeof yieldParametersSchema>;
export interface PublicYieldConfiguration {
  id: string;
  configKey: typeof YIELD_CONFIG_KEY;
  version: number;
  title: string;
  crop: 'MAIZE';
  expectedYieldKgPerHectare: string;
  applicability: string;
  assumptions: string[];
  source: z.infer<typeof calculatorSourceSchema>;
  engineVersion: typeof YIELD_ENGINE_VERSION;
  formulaVersion: typeof YIELD_FORMULA_VERSION;
  rounding: { mode: 'HALF_UP'; decimalPlaces: number };
}
export interface YieldCatalogue {
  status: 'READY' | 'PENDING_CONFIGURATION';
  message: string;
  engineVersion: typeof YIELD_ENGINE_VERSION;
  items: PublicYieldConfiguration[];
}
export interface YieldResult {
  input: YieldInput;
  normalizedArea: { value: string; unit: 'HECTARE' };
  expectedYield: { value: string; unit: 'KG' | 'TONNE'; unroundedValue: string };
  configuration: PublicYieldConfiguration;
  rounding: { mode: 'HALF_UP'; decimalPlaces: number };
  engineVersion: typeof YIELD_ENGINE_VERSION;
  formulaVersion: typeof YIELD_FORMULA_VERSION;
  explanation: string;
  assumptions: string[];
  unitReference: { title: string; url: string };
}
