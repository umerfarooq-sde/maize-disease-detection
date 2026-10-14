import { AppError } from '../../errors/app-error.js';
import {
  type CalculatorInput,
  calculatorInputSchema,
  FERTILIZER_CONFIG_KEY,
  FERTILIZER_ENGINE_VERSION,
  FERTILIZER_UNIT_REFERENCE,
  type FertilizerResult,
  fertilizerConfigParametersSchema,
  fertilizerDecimalSchema,
  type PublicFertilizerRule,
} from './fertilizer.types.js';

interface ExactDecimal {
  atoms: bigint;
  scale: number;
}
function decimal(value: string): ExactDecimal {
  const [whole = '0', fraction = ''] = value.split('.');
  return { atoms: BigInt(whole + fraction), scale: fraction.length };
}
function exactText(value: ExactDecimal): string {
  if (!value.atoms) return '0';
  if (!value.scale) return String(value.atoms);
  const digits = value.atoms.toString().padStart(value.scale + 1, '0');
  return `${digits.slice(0, -value.scale)}.${digits.slice(-value.scale)}`.replace(/\.?0+$/, '');
}
function roundedText(value: ExactDecimal, places: number): string {
  let atoms: bigint;
  if (value.scale > places) {
    const divisor = 10n ** BigInt(value.scale - places);
    atoms = value.atoms / divisor;
    if ((value.atoms % divisor) * 2n >= divisor) atoms++;
  } else atoms = value.atoms * 10n ** BigInt(places - value.scale);
  if (!places) return String(atoms);
  const digits = atoms.toString().padStart(places + 1, '0');
  return `${digits.slice(0, -places)}.${digits.slice(-places)}`;
}

/** Scale a reviewed product rate. This does not select or invent an agronomic rate. */
export function calculateFertilizer(
  input: CalculatorInput,
  rule: PublicFertilizerRule,
): FertilizerResult {
  const parsed = calculatorInputSchema.safeParse(input);
  if (!parsed.success) throw new AppError('VALIDATION_ERROR');
  const admittedRate = fertilizerDecimalSchema.safeParse(rule.rateKgPerHectare);
  if (
    input.ruleId !== rule.id ||
    input.ruleVersion !== rule.version ||
    input.configVersion !== rule.config.version
  )
    throw new AppError('FERTILIZER_CONFIGURATION_CHANGED');
  const config = fertilizerConfigParametersSchema.safeParse({
    algorithm: 'AREA_RATE_V1',
    crop: rule.crop,
    engineVersion: rule.config.engineVersion,
    quantityDecimalPlaces: rule.config.quantityDecimalPlaces,
    roundingMode: rule.config.roundingMode,
  });
  if (!config.success || rule.config.key !== FERTILIZER_CONFIG_KEY || !admittedRate.success) {
    throw new AppError('FERTILIZER_CONFIGURATION_INVALID');
  }
  const area = decimal(parsed.data.area);
  // NIST's international-acre definition is exactly 0.40468564224 hectares.
  const hectares =
    parsed.data.areaUnit === 'ACRE'
      ? { atoms: area.atoms * 40468564224n, scale: area.scale + 11 }
      : area;
  const rate = decimal(admittedRate.data);
  const quantity = { atoms: hectares.atoms * rate.atoms, scale: hectares.scale + rate.scale };
  if (parsed.data.outputUnit === 'G') quantity.atoms *= 1000n;
  const places = config.data.quantityDecimalPlaces;
  const value = roundedText(quantity, places);
  const unroundedValue = exactText(quantity);
  return {
    input: parsed.data,
    normalizedArea: { value: exactText(hectares), unit: 'HECTARE' },
    quantity: { value, unit: parsed.data.outputUnit, unroundedValue },
    rounding: { mode: 'HALF_UP', decimalPlaces: places },
    rule,
    engineVersion: FERTILIZER_ENGINE_VERSION,
    explanation:
      'The entered area is converted exactly to hectares and multiplied by the selected ' +
      'reviewed product rate in kg per hectare. Grams use exactly 1000 g per kg. Only the final ' +
      'quantity is rounded HALF_UP in the selected output unit; the unrounded quantity is disclosed.',
    assumptions: [
      ...rule.assumptions,
      'This scales the selected product rate; it does not assess soil nutrient need or choose a fertilizer dose.',
      'ACRE means the international acre: exactly 0.40468564224 hectares.',
      ...(value.replace(/[0.]/g, '') === '' && quantity.atoms > 0n
        ? [
            'The positive quantity is below the selected display precision; a rounded zero is not a recommendation to apply nothing.',
          ]
        : []),
    ],
    unitReference: FERTILIZER_UNIT_REFERENCE,
  };
}
