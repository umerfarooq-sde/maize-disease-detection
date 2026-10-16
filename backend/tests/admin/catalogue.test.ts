import assert from 'node:assert/strict';
import { test } from 'node:test';
import {
  catalogueMetadataSchema,
  diseaseCreateSchema,
  diseaseEditSchema,
  supportedDiseases,
} from '../../src/modules/admin/management.types.js';
import { createKnowledgeService } from '../../src/modules/knowledge/knowledge.service.js';
import { knowledgeDraft } from './management.helpers.js';
import { memoryKnowledge } from '../knowledge/helpers.js';
test('optional applicability requires reviewed attributable evidence; unsupported values are never defaulted', () => {
  const metadata = {
    growthStages: [],
    severityDescriptors: [],
    source: null,
    reviewNote: 'Explicitly clear unapproved optional applicability.',
    approved: true,
  };
  assert.equal(catalogueMetadataSchema.safeParse(metadata).success, true);
  assert.equal(
    catalogueMetadataSchema.safeParse({ ...metadata, growthStages: ['Synthetic stage'] }).success,
    false,
  );
  assert.equal(
    catalogueMetadataSchema.safeParse({
      ...metadata,
      severityDescriptors: ['Synthetic severity'],
      source: knowledgeDraft().source,
    }).success,
    true,
  );
  assert.equal(catalogueMetadataSchema.safeParse({ ...metadata, approved: false }).success, false);
});
test('informational catalogue creation cannot add/rename a trained model class', () => {
  const input = {
    slug: 'synthetic-information',
    name: 'Synthetic informational entry',
    scientificName: null,
    description: 'Synthetic fixture only',
    status: 'INACTIVE',
    source: knowledgeDraft().source,
    reviewNote: 'Isolated synthetic catalogue source review.',
    approved: true,
  };
  assert.equal(diseaseCreateSchema.safeParse(input).success, true);
  for (const item of supportedDiseases)
    assert.equal(diseaseCreateSchema.safeParse({ ...input, slug: item.slug }).success, false);
  assert.equal(
    diseaseCreateSchema.safeParse({ ...input, literalLabel: 'New_Model_Class' }).success,
    false,
  );
  assert.equal(
    diseaseEditSchema.safeParse({ ...input, expectedRevision: 'a'.repeat(64) }).success,
    false,
  );
  assert.deepEqual(
    supportedDiseases.map((item) => item.label),
    ['Common_Rust', 'Gray_Leaf_Spot', 'Healthy', 'Northern_Corn_Leaf_Blight'],
  );
});
test('Farmer details label informational entries separately and expose only reviewed applicability', async () => {
  const f = memoryKnowledge(),
    original = f.repository.findDisease;
  f.repository.findDisease = async (slug) => {
    const row = await original('common-rust');
    return row
      ? {
          ...row,
          slug,
          catalogueMetadata: {
            growthStages: ['Synthetic stage fixture'],
            severityDescriptors: [],
            source: knowledgeDraft().source,
            reviewNote: 'Isolated metadata review with no agronomic claims.',
            approved: true,
          },
        }
      : null;
  };
  const detail = await createKnowledgeService(f.repository, f.client).getDisease(
    'synthetic-information',
  );
  assert.equal(detail.catalogue?.classifierSupported, false);
  assert.equal(detail.catalogue?.literalLabel, null);
  assert.ok(JSON.stringify(detail.catalogue?.applicability).includes('Synthetic stage fixture'));
  const healthy = await createKnowledgeService(f.repository, f.client).getDisease('healthy');
  assert.equal(healthy.catalogue?.literalLabel, 'Healthy');
});
