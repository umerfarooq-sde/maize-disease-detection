import { z } from 'zod';

export const FERTILIZER_CONFIG_KEY = 'maize-area-rate' as const;
export const FERTILIZER_ENGINE_VERSION = 'area-rate-v1' as const;
export const FERTILIZER_UNIT_REFERENCE = {
  title: 'NIST Handbook 44 (2026), Appendix C: General Tables of Units of Measurement',
  url: 'https://www.nist.gov/system/files/documents/2025/12/30/appc-26-HB44-20251222.pdf',
} as const;
export const AREA_INPUT_SCALE = 6;
export const MAXIMUM_INPUT_AREA = '1000000';

/** Nonnegative fixed decimal; no binary floating-point, exponent or locale coercion. */
export function decimalWithin(value: string, maximum: string, scale = AREA_INPUT_SCALE): boolean {
  if (!new RegExp(`^(?:0|[1-9][0-9]{0,6})(?:\\.[0-9]{1,${scale}})?$`).test(value)) return false;
  const [whole = '0', fractional = ''] = value.split('.');
  return (
    BigInt(whole) * 10n ** BigInt(scale) + BigInt(fractional.padEnd(scale, '0')) <=
    BigInt(maximum) * 10n ** BigInt(scale)
  );
}

export const fertilizerDecimalSchema = z
  .string()
  .max(14)
  .trim()
  .refine((value) => decimalWithin(value, MAXIMUM_INPUT_AREA));
const positiveVersion = z.number().int().min(1).max(2_147_483_647);
const safeText = (maximum: number) =>
  z
    .string()
    .trim()
    .min(1)
    .max(maximum)
    .refine((value) => !value.includes('\0'));
const httpsReference = z
  .string()
  .max(2048)
  .refine((value) => {
    try {
      const url = new URL(value);
      return (
        url.protocol === 'https:' &&
        !url.username &&
        !url.password &&
        !Array.from(value).some((char) => {
          const code = char.codePointAt(0) ?? 0;
          return code <= 32 || code === 127 || /\s/u.test(char);
        })
      );
    } catch {
      return false;
    }
  });
export const fertilizerSourceSchema = z.strictObject({
  title: safeText(255),
  publisher: safeText(255),
  url: httpsReference,
  citation: safeText(1000),
});
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
