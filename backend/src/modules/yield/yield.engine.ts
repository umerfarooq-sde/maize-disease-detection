import { AppError } from '../../errors/app-error.js';
import { CALCULATOR_UNIT_REFERENCE } from '../calculators/calculator.contract.js';
import { scaleAreaRate } from '../calculators/exact-units.js';
import {
  type PublicYieldConfiguration,
  YIELD_CONFIG_KEY,
  YIELD_ENGINE_VERSION,
  YIELD_FORMULA_VERSION,
  type YieldInput,
  type YieldResult,
  yieldInputSchema,
  yieldParametersSchema,
} from './yield.types.js';

/** Dimensional projection only; source review must justify the configured rate and its applicability. */
export function calculateYield(
  input: YieldInput,
  configuration: PublicYieldConfiguration,
): YieldResult {
  const parsed = yieldInputSchema.safeParse(input);
  if (!parsed.success) throw new AppError('VALIDATION_ERROR');
  if (
    parsed.data.configId !== configuration.id ||
    parsed.data.configVersion !== configuration.version
  )
    throw new AppError('YIELD_CONFIGURATION_CHANGED');
  // Validate the calculation fields without manufacturing a review attestation.
  const calculation = yieldParametersSchema.omit({ approval: true }).safeParse({
    algorithm: 'AREA_TIMES_REVIEWED_YIELD_RATE_V1',
    engineVersion: configuration.engineVersion,
    formulaVersion: configuration.formulaVersion,
    crop: configuration.crop,
    title: configuration.title,
    expectedYieldKgPerHectare: configuration.expectedYieldKgPerHectare,
    applicability: configuration.applicability,
    assumptions: configuration.assumptions,
    source: configuration.source,
    quantityDecimalPlaces: configuration.rounding.decimalPlaces,
    roundingMode: configuration.rounding.mode,
  });
  if (!calculation.success || configuration.configKey !== YIELD_CONFIG_KEY)
    throw new AppError('YIELD_CONFIGURATION_INVALID');
  const values = scaleAreaRate({
    ...parsed.data,
    rateKgPerHectare: calculation.data.expectedYieldKgPerHectare,
    decimalPlaces: calculation.data.quantityDecimalPlaces,
  });
  return {
    input: parsed.data,
    normalizedArea: values.normalizedArea,
    expectedYield: values.quantity,
    configuration,
    rounding: configuration.rounding,
    engineVersion: YIELD_ENGINE_VERSION,
    formulaVersion: YIELD_FORMULA_VERSION,
    explanation:
      'The field area is converted exactly to hectares and multiplied by the reviewed expected kg per hectare. ' +
      'Metric tonnes use exactly 1000 kg per tonne. Only the final quantity is rounded HALF_UP in the selected unit. ' +
      'This is a conditional planning estimate, not a guaranteed harvest or a measured field forecast.',
    assumptions: [
      ...configuration.assumptions,
      'The reviewed rate applies uniformly to the entered area only under its stated conditions.',
      'No weather, disease loss, moisture, soil or plant-population adjustment is inferred.',
      'ACRE means the international acre: exactly 0.40468564224 hectares.',
      ...(values.positiveRoundedZero
        ? [
            'The positive expected quantity is below display precision; rounded zero does not mean zero expected harvest.',
          ]
        : []),
    ],
    unitReference: CALCULATOR_UNIT_REFERENCE,
  };
}
