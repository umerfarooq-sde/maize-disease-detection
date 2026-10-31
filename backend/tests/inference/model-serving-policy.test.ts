import assert from 'node:assert/strict';
import { test } from 'node:test';
import { canServeRegisteredModel } from '../../src/modules/inference/model-serving-policy.js';

const research = {
  researchPolicy: {
    permitted_use: 'non-commercial academic/FYP research only',
    commercial_clearance: false,
  },
};
const cleared = {
  researchPolicy: {
    permitted_use: 'commercial and academic use',
    commercial_clearance: true,
  },
};

test('production refuses validated, retired, unknown and research-only versions', () => {
  for (const status of ['DRAFT', 'VALIDATED', 'RETIRED', 'PRODUCTION'] as const) {
    assert.equal(
      canServeRegisteredModel({ status, trainingConfig: research }, 'production'),
      false,
    );
  }
  assert.equal(canServeRegisteredModel(null, 'production'), false);
  assert.equal(
    canServeRegisteredModel({ status: 'PRODUCTION', trainingConfig: {} }, 'production'),
    false,
  );
  assert.equal(
    canServeRegisteredModel(
      { status: 'PRODUCTION', trainingConfig: { researchPolicy: { commercial_clearance: true } } },
      'production',
    ),
    false,
  );
});

test('approved promoted models only are eligible for production', () => {
  assert.equal(
    canServeRegisteredModel({ status: 'PRODUCTION', trainingConfig: cleared }, 'production'),
    true,
  );
  assert.equal(
    canServeRegisteredModel({ status: 'VALIDATED', trainingConfig: cleared }, 'production'),
    false,
  );
});

test('research mode permits technically registered validated models, but not drafts or retired', () => {
  assert.equal(
    canServeRegisteredModel({ status: 'VALIDATED', trainingConfig: research }, 'development'),
    true,
  );
  assert.equal(
    canServeRegisteredModel({ status: 'VALIDATED', trainingConfig: research }, 'test'),
    true,
  );
  assert.equal(
    canServeRegisteredModel({ status: 'RETIRED', trainingConfig: research }, 'test'),
    false,
  );
});
