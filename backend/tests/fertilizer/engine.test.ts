import assert from 'node:assert/strict';
import { test } from 'node:test';
import { AppError } from '../../src/errors/app-error.js';
import { calculateFertilizer } from '../../src/modules/fertilizer/fertilizer.engine.js';
import {
  type CalculatorInput,
  calculatorInputSchema,
  type PublicFertilizerRule,
} from '../../src/modules/fertilizer/fertilizer.types.js';

// Arbitrary arithmetic fixtures only: never seed or publish these as agronomic rates.
function rule(rate = '10.2', places = 3): PublicFertilizerRule {
  return {
    id: '00000000-0000-4000-8000-000000000001',
    ruleKey: 'synthetic-test',
    version: 1,
    title: 'SYNTHETIC ARITHMETIC FIXTURE; NOT AGRONOMIC ADVICE',
    crop: 'MAIZE',
    fertilizer: { slug: 'synthetic-product', name: 'Synthetic arithmetic product' },
    rateKgPerHectare: rate,
    applicability: 'Tests only; not suitable for field use.',
    assumptions: ['Arbitrary synthetic test rate, not a fertilizer recommendation.'],
    source: {
      title: 'Synthetic test fixture',
      publisher: 'Test suite only',
      url: 'https://example.invalid/synthetic-test',
      citation: 'Not an agricultural source.',
    },
    config: {
      key: 'maize-area-rate',
      version: 1,
      engineVersion: 'area-rate-v1',
      quantityDecimalPlaces: places,
      roundingMode: 'HALF_UP',
    },
  };
}
function input(
  area = '1.25',
  areaUnit: 'HECTARE' | 'ACRE' = 'HECTARE',
  outputUnit: 'KG' | 'G' = 'KG',
): CalculatorInput {
  return { area, areaUnit, outputUnit, ruleId: rule().id, ruleVersion: 1, configVersion: 1 };
}
const fails = (code: string) => (error: unknown) =>
  error instanceof AppError && error.code === code;

test('exact decimal area-rate scaling preserves the inputs, source, versions and repeatability', () => {
  const result = calculateFertilizer(input(), rule());
  assert.deepEqual(result.quantity, { value: '12.750', unit: 'KG', unroundedValue: '12.75' });
  assert.deepEqual(result.normalizedArea, { value: '1.25', unit: 'HECTARE' });
  assert.equal(result.rule.version, 1);
  assert.equal(result.rule.config.version, 1);
  assert.equal(result.rule.source.url, rule().source.url);
  assert.match(result.explanation, /reviewed product rate/);
  assert.deepEqual(calculateFertilizer(input(), rule()), result);
});
test('international-acre conversion uses all exact digits without intermediate rounding', () => {
  const result = calculateFertilizer(input('2', 'ACRE'), rule('50'));
  assert.equal(result.normalizedArea.value, '0.80937128448');
  assert.equal(result.quantity.unroundedValue, '40.468564224');
  assert.equal(result.quantity.value, '40.469');
  assert.match(result.unitReference.url, /^https:\/\/www.nist.gov\//);
  const grams = calculateFertilizer(input('2', 'ACRE', 'G'), rule('50'));
  assert.equal(grams.quantity.unroundedValue, '40468.564224');
  assert.equal(grams.quantity.value, '40468.564');
});
test('kg and grams are explicit exact quantities, including common binary-float trouble', () => {
  assert.equal(calculateFertilizer(input('0.1'), rule('0.2')).quantity.unroundedValue, '0.02');
  const result = calculateFertilizer(input('1.234', 'HECTARE', 'G'), rule('2.5'));
  assert.deepEqual(result.quantity, { value: '3085.000', unit: 'G', unroundedValue: '3085' });
});
test('half-up ties, precision policy and tiny positive rounded zeros are disclosed', () => {
  assert.equal(calculateFertilizer(input('0.05'), rule('10', 0)).quantity.value, '1');
  const small = calculateFertilizer(input('0.049999'), rule('10', 0));
  assert.equal(small.quantity.value, '0');
  assert.equal(small.quantity.unroundedValue, '0.49999');
  assert.ok(
    small.assumptions.some((item) => item.includes('not a recommendation to apply nothing')),
  );
  const expected = ['12', '12.3', '12.35', '12.346', '12.3457', '12.34568', '12.345678'];
  expected.forEach((value, places) => {
    assert.equal(calculateFertilizer(input('1'), rule('12.345678', places)).quantity.value, value);
  });
});
test('minimum/maximum operational bounds and reviewed zero rate are exact', () => {
  const minimum = calculateFertilizer(input('0.000001'), rule('0.000001'));
  assert.equal(minimum.quantity.unroundedValue, '0.000000000001');
  const maximum = calculateFertilizer(input('1000000', 'HECTARE', 'G'), rule('1000000'));
  assert.equal(maximum.quantity.value, '1000000000000000.000');
  assert.deepEqual(calculateFertilizer(input('1'), rule('0')).quantity, {
    value: '0.000',
    unit: 'KG',
    unroundedValue: '0',
  });
});
for (const value of [
  '',
  '0',
  '-1',
  '01',
  '.5',
  '1.',
  '1e3',
  '1,2',
  'NaN',
  'Infinity',
  '1000000.000001',
  '0.0000001',
]) {
  test(`reject nonpositive/ambiguous/out-of-bounds area ${JSON.stringify(value)}`, () => {
    assert.equal(calculatorInputSchema.safeParse(input(value)).success, false);
    assert.throws(() => calculateFertilizer(input(value), rule()), fails('VALIDATION_ERROR'));
  });
}
test('missing fields, numeric JSON, unsupported units and client-provided rates/formulas fail admission', () => {
  for (const value of [
    {},
    { ...input(), area: 1 },
    { ...input(), areaUnit: 'SQUARE_FEET' },
    { ...input(), outputUnit: 'TON' },
    { ...input(), rateKgPerHectare: '999' },
    { ...input(), formula: 'eval' },
    { ...input(), ruleVersion: 0 },
  ]) {
    assert.equal(calculatorInputSchema.safeParse(value).success, false);
  }
});
test('stale rule/config pins and incompatible engine settings fail rather than guessing', () => {
  assert.throws(
    () => calculateFertilizer({ ...input(), ruleVersion: 2 }, rule()),
    fails('FERTILIZER_CONFIGURATION_CHANGED'),
  );
  assert.throws(
    () => calculateFertilizer({ ...input(), configVersion: 2 }, rule()),
    fails('FERTILIZER_CONFIGURATION_CHANGED'),
  );
  const invalid = { ...rule(), config: { ...rule().config, quantityDecimalPlaces: 7 } };
  assert.throws(
    () => calculateFertilizer(input(), invalid),
    fails('FERTILIZER_CONFIGURATION_INVALID'),
  );
  assert.throws(
    () => calculateFertilizer(input(), rule('-1')),
    fails('FERTILIZER_CONFIGURATION_INVALID'),
  );
});
