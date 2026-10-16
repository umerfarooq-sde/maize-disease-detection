import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import { test } from 'node:test';
import { modelSpecification } from '../../src/modules/calculators/model-specification.types.js';
import { createSpecificationService } from '../../src/modules/calculators/model-specification.service.js';
import type { SpecificationRepository } from '../../src/modules/calculators/model-specification.repository.js';
import { yieldParametersSchema } from '../../src/modules/yield/yield.types.js';
import { fertilizerConfigParametersSchema } from '../../src/modules/fertilizer/fertilizer.types.js';
export function syntheticSpecification() {
  return {
    modelKey: 'synthetic-review-only',
    kind: 'YIELD',
    expectedVersion: 0,
    title: 'Synthetic model specification',
    mathematicalDefinition:
      'Synthetic dimensional definitions for contract testing only; no field model is approved.',
    applicability: 'Isolated tests only',
    assumptions: ['No agronomic validity is claimed.'],
    inputs: [{ key: 'area', unit: 'HECTARE', description: 'Synthetic area variable.' }],
    outputs: ['minimum', 'expected', 'potential'].map((key) => ({
      key,
      unit: 'KG',
      description: 'Synthetic conditional output.',
    })),
    coefficients: [],
    source: {
      url: 'https://example.invalid/model',
      title: 'Synthetic model reference',
      publisher: 'Test generator',
      citation: 'Synthetic, not an agronomic source.',
    },
    reviewNote: 'Review this synthetic contract without approving a field calculation.',
    approved: true,
  };
}
test('richer model intake preserves explicit units and rejects missing scientific contracts', () => {
  const valid = syntheticSpecification();
  assert.equal(modelSpecification.safeParse(valid).success, true);
  for (const change of [
    { approved: false },
    { outputs: [] },
    { mathematicalDefinition: 'unknown' },
    { inputs: [{ key: 'area', unit: 'ACRE_OR_HA', description: 'Mixed units' }] },
    { coefficients: [{ key: 'dose', value: 1, unit: 'KG', sourceSection: 'Unknown' }] },
    { coefficients: [{ key: 'dose', value: '1', unit: 'KG', sourceSection: '' }] },
    { inputs: [valid.inputs[0], valid.inputs[0]] },
    { execution: 'ENABLED' },
  ])
    assert.equal(modelSpecification.safeParse({ ...valid, ...change }).success, false);
});
test('fertilizer model contract requires explicit N/P/K outputs without inventing doses', () => {
  const valid = {
    ...syntheticSpecification(),
    kind: 'FERTILIZER',
    outputs: ['nitrogen', 'phosphorus', 'potassium'].map((key) => ({
      key,
      unit: 'KG_PER_HECTARE',
      description: 'Synthetic output definition only.',
    })),
  };
  assert.equal(modelSpecification.safeParse(valid).success, true);
  assert.equal(
    modelSpecification.safeParse({ ...valid, outputs: valid.outputs.slice(0, 2) }).success,
    false,
  );
});
test('review intake is immutable draft metadata and never an executable calculator configuration', async () => {
  const input = modelSpecification.parse(syntheticSpecification());
  const parameters = {
    purpose: 'MODEL_SPECIFICATION_ONLY',
    domainApproval: 'PENDING_DOMAIN_APPROVAL',
    execution: 'DISABLED',
    input,
    reviewedAt: new Date().toISOString(),
  };
  const row = {
    id: randomUUID(),
    kind: 'YIELD' as const,
    configKey: 'model-intake.synthetic-review-only',
    version: 1,
    parameters,
    unit: 'SPECIFICATION_ONLY',
    sourceReference: input.source.url,
    status: 'DRAFT' as const,
    createdById: randomUUID(),
    createdAt: new Date(),
    updatedAt: new Date(),
  };
  const repository: SpecificationRepository = {
    async list() {
      return [row];
    },
    async create() {
      return row;
    },
  };
  const result = (await createSpecificationService(repository).list()).items[0];
  assert.equal(result?.execution, 'DISABLED');
  assert.equal(result?.validForActivation, false);
  assert.equal(result?.domainApproval, 'PENDING_DOMAIN_APPROVAL');
  assert.equal(yieldParametersSchema.safeParse(parameters).success, false);
  assert.equal(fertilizerConfigParametersSchema.safeParse(parameters).success, false);
});
