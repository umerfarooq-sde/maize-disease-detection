import { z } from 'zod';

export const CALCULATOR_UNIT_REFERENCE = {
  title: 'NIST Handbook 44 (2026), Appendix C: General Tables of Units of Measurement',
  url: 'https://www.nist.gov/system/files/documents/2025/12/30/appc-26-HB44-20251222.pdf',
} as const;
export const AREA_INPUT_SCALE = 6;
export const MAXIMUM_INPUT_AREA = '1000000';

/** Bounded decimal admission, never binary floating-point coercion. */
export function decimalWithin(value: string, maximum: string, scale = AREA_INPUT_SCALE): boolean {
  if (!new RegExp(`^(?:0|[1-9][0-9]{0,6})(?:\\.[0-9]{1,${scale}})?$`).test(value)) return false;
  const [whole = '0', fractional = ''] = value.split('.');
  return (
    BigInt(whole) * 10n ** BigInt(scale) + BigInt(fractional.padEnd(scale, '0')) <=
    BigInt(maximum) * 10n ** BigInt(scale)
  );
}
export const calculatorDecimalSchema = z
  .string()
  .max(14)
  .trim()
  .refine((value) => decimalWithin(value, MAXIMUM_INPUT_AREA));
export const calculatorAreaSchema = calculatorDecimalSchema.refine((value) => /[1-9]/.test(value));
export const calculatorVersionSchema = z.number().int().min(1).max(2_147_483_647);
export const calculatorText = (maximum: number) =>
  z
    .string()
    .trim()
    .min(1)
    .max(maximum)
    .refine((value) => !value.includes('\0'));
export const calculatorHttpsReference = z
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
export const calculatorSourceSchema = z.strictObject({
  title: calculatorText(255),
  publisher: calculatorText(255),
  url: calculatorHttpsReference,
  citation: calculatorText(1000),
});
