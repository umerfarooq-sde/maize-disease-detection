import { z } from 'zod';
import {
  CALCULATOR_UNIT_REFERENCE,
  calculatorDecimalSchema,
  calculatorSourceSchema,
  decimalWithin,
  calculatorHttpsReference as httpsReference,
  calculatorVersionSchema as positiveVersion,
  calculatorText as safeText,
} from '../calculators/calculator.contract.js';

export {
  AREA_INPUT_SCALE,
  decimalWithin,
  MAXIMUM_INPUT_AREA,
} from '../calculators/calculator.contract.js';

export const FERTILIZER_CONFIG_KEY = 'maize-area-rate' as const;
export const FERTILIZER_ENGINE_VERSION = 'area-rate-v1' as const;
export const FERTILIZER_UNIT_REFERENCE = CALCULATOR_UNIT_REFERENCE;
export const fertilizerDecimalSchema = calculatorDecimalSchema;
export const fertilizerSourceSchema = calculatorSourceSchema;
export const fertilizerProductSnapshotSchema = z.strictObject({
  slug: z
    .string()
    .max(120)
    .regex(/^[a-z0-9]+(?:-[a-z0-9]+)*$/),
  name: safeText(160),
  description: safeText(2000),
  nitrogenPercent: z.string().refine((value) => decimalWithin(value, '100', 2)),
  phosphorusPercent: z.string().refine((value) => decimalWithin(value, '100', 2)),
  potassiumPercent: z.string().refine((value) => decimalWithin(value, '100', 2)),
  applicationMethod: safeText(1600).nullable(),
  precautions: z.array(safeText(400)).max(8),
  sourceReference: httpsReference,
});
export const fertilizerConfigParametersSchema = z.strictObject({
  algorithm: z.literal('AREA_RATE_V1'),
  engineVersion: z.literal(FERTILIZER_ENGINE_VERSION),
  crop: z.literal('MAIZE'),
  quantityDecimalPlaces: z.number().int().min(0).max(6),
  roundingMode: z.literal('HALF_UP'),
});
export const fertilizerRuleParametersSchema = z.strictObject({
  algorithm: z.literal('AREA_RATE_V1'),
  crop: z.literal('MAIZE'),
  configVersion: positiveVersion,
  title: safeText(255),
  rateKgPerHectare: fertilizerDecimalSchema,
  applicability: safeText(2000),
  assumptions: z.array(safeText(400)).min(1).max(8),
  source: fertilizerSourceSchema,
  productSnapshot: fertilizerProductSnapshotSchema,
  approval: z.strictObject({
    status: z.literal('PROJECT_APPROVED_SOURCE'),
    reviewedAt: z.iso.datetime(),
    reviewedBy: z.uuid(),
    note: safeText(2000),
  }),
});
export const calculatorInputSchema = z.strictObject({
  area: fertilizerDecimalSchema.refine((value) => /[1-9]/.test(value)),
  areaUnit: z.enum(['HECTARE', 'ACRE']),
  outputUnit: z.enum(['KG', 'G']),
  ruleId: z.uuid(),
  ruleVersion: positiveVersion,
  configVersion: positiveVersion,
});
export type CalculatorInput = z.infer<typeof calculatorInputSchema>;
export type FertilizerRuleParameters = z.infer<typeof fertilizerRuleParametersSchema>;
export type FertilizerConfigParameters = z.infer<typeof fertilizerConfigParametersSchema>;
export type FertilizerSource = z.infer<typeof fertilizerSourceSchema>;
export type FertilizerProductSnapshot = z.infer<typeof fertilizerProductSnapshotSchema>;

export interface PublicFertilizerRule {
  id: string;
  ruleKey: string;
  version: number;
  title: string;
  crop: 'MAIZE';
  fertilizer: { slug: string; name: string };
  rateKgPerHectare: string;
  applicability: string;
  assumptions: string[];
  source: FertilizerSource;
  config: {
    key: typeof FERTILIZER_CONFIG_KEY;
    version: number;
    engineVersion: typeof FERTILIZER_ENGINE_VERSION;
    quantityDecimalPlaces: number;
    roundingMode: 'HALF_UP';
  };
}
export interface FertilizerCatalogue {
  status: 'READY' | 'PENDING_RULES';
  message: string;
  engineVersion: typeof FERTILIZER_ENGINE_VERSION;
  items: PublicFertilizerRule[];
}
export interface FertilizerResult {
  input: CalculatorInput;
  normalizedArea: { value: string; unit: 'HECTARE' };
  quantity: { value: string; unit: 'KG' | 'G'; unroundedValue: string };
  rounding: { mode: 'HALF_UP'; decimalPlaces: number };
  rule: PublicFertilizerRule;
  engineVersion: typeof FERTILIZER_ENGINE_VERSION;
  explanation: string;
  assumptions: string[];
  unitReference: { title: string; url: string };
}
