import assert from 'node:assert/strict';
import { test } from 'node:test';
import { AppError } from '../../src/errors/app-error.js';
import { calculateYield } from '../../src/modules/yield/yield.engine.js';
import { publicYieldConfiguration } from '../../src/modules/yield/yield.service.js';
import { yieldInputSchema } from '../../src/modules/yield/yield.types.js';
import { configuration, input } from './helpers.js';

const publicConfig = () => {
  const value = publicYieldConfiguration(configuration());
  assert.ok(value);
  return value;
};
const fails = (code: string) => (error: unknown) =>
  error instanceof AppError && error.code === code;
test('yield projection preserves exact decimal inputs, provenance, assumptions and versions', () => {
  const config = publicConfig();
  const request = input(config.id, { area: '1.250000' });
  const result = calculateYield(request, config);
  assert.deepEqual(result.expectedYield, { value: '15.625', unit: 'KG', unroundedValue: '15.625' });
  assert.equal(result.normalizedArea.value, '1.25');
  assert.deepEqual(result.input, request);
  assert.deepEqual(result.configuration.source, config.source);
  assert.equal(result.configuration.version, 1);
  assert.equal(result.formulaVersion, 'area-times-reviewed-yield-rate-v1');
  assert.match(result.explanation, /conditional planning estimate/);
  assert.deepEqual(calculateYield(request, config), result);
});
test('international acres and metric tonnes are exact without intermediate rounding', () => {
  const config = { ...publicConfig(), expectedYieldKgPerHectare: '50' };
  const kilograms = calculateYield(input(config.id, { areaUnit: 'ACRE' }), config);
  assert.equal(kilograms.normalizedArea.value, '0.80937128448');
  assert.equal(kilograms.expectedYield.unroundedValue, '40.468564224');
  assert.equal(kilograms.expectedYield.value, '40.469');
  const tonnes = calculateYield(
    input(config.id, { areaUnit: 'ACRE', outputUnit: 'TONNE' }),
    config,
  );
  assert.deepEqual(tonnes.expectedYield, {
    value: '0.040',
    unit: 'TONNE',
    unroundedValue: '0.040468564224',
  });
  assert.equal(
    calculateYield(input(config.id, { area: '20', outputUnit: 'TONNE' }), config).expectedYield
      .value,
    '1.000',
  );
});
test('decimal precision, HALF_UP ties and positive rounded-zero warning are deterministic', () => {
  const config = publicConfig();
  const exact = { ...config, expectedYieldKgPerHectare: '0.2' };
  assert.equal(
    calculateYield(input(config.id, { area: '0.1' }), exact).expectedYield.unroundedValue,
    '0.02',
  );
  const rounded = {
    ...config,
    expectedYieldKgPerHectare: '0.5',
    rounding: { mode: 'HALF_UP' as const, decimalPlaces: 0 },
  };
  assert.equal(calculateYield(input(config.id, { area: '1' }), rounded).expectedYield.value, '1');
  const tiny = calculateYield(input(config.id, { area: '0.000001', outputUnit: 'TONNE' }), {
    ...config,
    expectedYieldKgPerHectare: '0.000001',
  });
  assert.equal(tiny.expectedYield.unroundedValue, '0.000000000000001');
  assert.ok(tiny.assumptions.some((value) => value.includes('below display precision')));
});
test('maximum supported area/rate and reviewed zero scenario do not overflow or fabricate yield', () => {
  const config = publicConfig();
  assert.equal(
    calculateYield(input(config.id, { area: '1000000' }), {
      ...config,
      expectedYieldKgPerHectare: '1000000',
    }).expectedYield.value,
    '1000000000000.000',
  );
  assert.equal(
    calculateYield(input(config.id), { ...config, expectedYieldKgPerHectare: '0' }).expectedYield
      .value,
    '0.000',
  );
});
for (const area of [
  '',
  '0',
  '-1',
  '01',
  '.5',
  '1.',
  'NaN',
  'Infinity',
  '1e3',
  '1,2',
  '1000000.000001',
  '0.0000001',
]) {
  test(`reject invalid yield area ${JSON.stringify(area)}`, () => {
    const config = publicConfig();
    assert.throws(
      () => calculateYield(input(config.id, { area }), config),
      fails('VALIDATION_ERROR'),
    );
  });
}
test('missing fields, JSON numbers, unsupported units and client formulas/rates fail admission', () => {
  const config = publicConfig();
  for (const value of [
    {},
    { ...input(config.id), area: 2 },
    { ...input(config.id), areaUnit: 'MU' },
    { ...input(config.id), outputUnit: 'TON' },
    { ...input(config.id), expectedYieldKgPerHectare: '99' },
    { ...input(config.id), formula: 'area*rate' },
  ])
    assert.equal(yieldInputSchema.safeParse(value).success, false);
});
test('stale pins and incompatible formula/engine/rounding/rate fail closed', () => {
  const config = publicConfig();
  assert.throws(
    () => calculateYield(input(config.id, { configVersion: 2 }), config),
    fails('YIELD_CONFIGURATION_CHANGED'),
  );
  for (const invalid of [
    { ...config, rounding: { mode: 'HALF_UP' as const, decimalPlaces: 7 } },
    { ...config, expectedYieldKgPerHectare: '-1' },
    { ...config, expectedYieldKgPerHectare: '1000000.1' },
  ])
    assert.throws(
      () => calculateYield(input(config.id), invalid),
      fails('YIELD_CONFIGURATION_INVALID'),
    );
});
