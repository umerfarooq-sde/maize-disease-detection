import { AppError } from '../../errors/app-error.js';
import { scaleAreaRate } from '../calculators/exact-units.js';
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
  const places = config.data.quantityDecimalPlaces;
  const { normalizedArea, quantity, positiveRoundedZero } = scaleAreaRate({
    area: parsed.data.area,
    areaUnit: parsed.data.areaUnit,
    rateKgPerHectare: admittedRate.data,
    outputUnit: parsed.data.outputUnit,
    decimalPlaces: places,
  });
  return {
    input: parsed.data,
    normalizedArea,
    quantity,
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
      ...(positiveRoundedZero
        ? [
            'The positive quantity is below the selected display precision; a rounded zero is not a recommendation to apply nothing.',
          ]
        : []),
    ],
    unitReference: FERTILIZER_UNIT_REFERENCE,
  };
}
