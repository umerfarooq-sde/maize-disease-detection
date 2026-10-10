import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { mkdtemp, readFile, rmdir, unlink, writeFile } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { test, type TestContext } from 'node:test';
import { fileURLToPath } from 'node:url';
import { diseaseLabels } from '../../src/modules/inference/inference.types.js';
import { readApprovedModel } from '../../src/modules/inference/model-registration.js';

const approvedMetadataPath = fileURLToPath(
  new URL(
    '../../../ml-training/reports/mobilenet-v3-small-20261009-v2-01-fitness/model-artifact.json',
    import.meta.url,
  ),
);
const approvedMetadataSha256 = 'a831116fe1ff8b915543991412f4ab6b334736e8eaca376fab8db3b57e5b263d';
const approvedCheckpointSha256 = 'e95a2e83262637fc1a08b919e6003bddb2fe70664b9c51418f059b7c8287dc66';
const approvedModelVersion = 'mobilenet-v3-small-v2-20261009';
const approvedPreprocessingVersion = '1.0.0';
const digest = (bytes: Uint8Array) => createHash('sha256').update(bytes).digest('hex');

function object(value: unknown): Record<string, unknown> {
  assert.ok(value !== null && typeof value === 'object' && !Array.isArray(value));
  return value as Record<string, unknown>;
}

async function temporaryMetadata(context: TestContext, bytes: Uint8Array) {
  const directory = await mkdtemp(join(tmpdir(), 'maizedoctor-registration-test-'));
  const path = join(directory, 'model-artifact.json');
  await writeFile(path, bytes);
  context.after(async () => {
    // Remove only the exact file and empty directory created by this fixture.
    // Source metadata, model weights and dataset files are never modified.
    await unlink(path);
    await rmdir(directory);
  });
  return { path, sha256: digest(bytes) };
}

async function sourceMetadata(): Promise<Record<string, unknown>> {
  return object(JSON.parse(await readFile(approvedMetadataPath, 'utf8')) as unknown);
}

test('approved research metadata registers exact classifier identity without model paths or production promotion', async () => {
  assert.equal(digest(await readFile(approvedMetadataPath)), approvedMetadataSha256);
  const model = await readApprovedModel(
    approvedMetadataPath,
    approvedMetadataSha256,
    approvedModelVersion,
    approvedPreprocessingVersion,
  );
  assert.equal(model.version, approvedModelVersion);
  assert.equal(model.architecture, 'mobilenet_v3_small');
  assert.equal(model.artifactUri, `sha256:${approvedCheckpointSha256}`);
  assert.equal(model.artifactSha256, approvedCheckpointSha256);
  assert.equal(model.datasetVersion, 'maize-research-20261008-v2');
  assert.equal(model.preprocessingVersion, approvedPreprocessingVersion);
  assert.deepEqual(model.classLabels, diseaseLabels);
  assert.equal(model.status, 'VALIDATED');
  assert.equal(model.trainingConfig.metadataSha256, approvedMetadataSha256);
  assert.equal(model.trainingConfig.experimentId, 'mobilenet-v3-small-20261009-v2-01');
  assert.equal(model.trainingConfig.seed, 20261007);
  assert.equal(
    model.trainingConfig.preprocessingHash,
    'b142e59f458d27a2d3fddbfc86c2f2f802670ab4909f1275babbef92de9cb5c8',
  );
  assert.equal(
    model.trainingConfig.manifestFingerprint,
    'a96fd5d32a8e0696df7cfc5bbfa6b78941c8a2f308f940ce295147a8832a583b',
  );
  assert.deepEqual(model.trainingConfig.researchPolicy, {
    permitted_use: 'non-commercial academic/FYP research only',
    commercial_clearance: false,
    raw_image_redistribution: false,
  });
  const source = await sourceMetadata();
  assert.deepEqual(model.trainingConfig.hyperparameters, object(source.training).hyperparameters);
  assert.deepEqual(model.trainingConfig.preprocessing, object(source.preprocessing).configuration);
  assert.ok(!JSON.stringify(model).includes('.cache/'));
  assert.equal(digest(await readFile(approvedMetadataPath)), approvedMetadataSha256);
});

test('exact copied metadata preserves pinned identity and maximum metadata size is inclusive', async (context) => {
  const bytes = await readFile(approvedMetadataPath);
  const exact = await temporaryMetadata(context, bytes);
  const paddedBytes = Buffer.concat([bytes, Buffer.alloc(512 * 1024 - bytes.length, 0x20)]);
  const padded = await temporaryMetadata(context, paddedBytes);
  const original = await readApprovedModel(
    exact.path,
    approvedMetadataSha256,
    approvedModelVersion,
    approvedPreprocessingVersion,
  );
  const boundary = await readApprovedModel(
    padded.path,
    padded.sha256,
    approvedModelVersion,
    approvedPreprocessingVersion,
  );
  assert.equal(original.artifactSha256, boundary.artifactSha256);
  assert.equal(boundary.trainingConfig.metadataSha256, padded.sha256);
});

test('missing, malformed, oversized or unpinned metadata fails before registration', async (context) => {
  const bytes = await readFile(approvedMetadataPath);
  const exact = await temporaryMetadata(context, bytes);
  await assert.rejects(
    readApprovedModel(`${exact.path}.missing`, exact.sha256, approvedModelVersion, '1.0.0'),
  );
  for (const hash of ['', 'not-a-digest', 'A'.repeat(64), '0'.repeat(64)]) {
    await assert.rejects(
      readApprovedModel(exact.path, hash, approvedModelVersion, '1.0.0'),
      /integrity check failed/,
    );
  }
  const malformed = await temporaryMetadata(context, Buffer.from('{invalid-json'));
  await assert.rejects(
    readApprovedModel(malformed.path, malformed.sha256, approvedModelVersion, '1.0.0'),
    SyntaxError,
  );
  const oversized = await temporaryMetadata(
    context,
    Buffer.concat([bytes, Buffer.alloc(512 * 1024 + 1 - bytes.length, 0x20)]),
  );
  await assert.rejects(
    readApprovedModel(oversized.path, oversized.sha256, approvedModelVersion, '1.0.0'),
    /integrity check failed/,
  );
  const rewritten = await temporaryMetadata(
    context,
    Buffer.from(JSON.stringify(await sourceMetadata())),
  );
  await assert.rejects(
    readApprovedModel(rewritten.path, approvedMetadataSha256, approvedModelVersion, '1.0.0'),
    /integrity check failed/,
  );
});

test('registration rejects mismatched configured artifact versions even for trusted metadata', async () => {
  for (const [modelVersion, preprocessingVersion] of [
    ['different-classifier', approvedPreprocessingVersion],
    [approvedModelVersion, 'different-preprocessing'],
    ['', approvedPreprocessingVersion],
    [approvedModelVersion, ''],
  ]) {
    await assert.rejects(
      readApprovedModel(
        approvedMetadataPath,
        approvedMetadataSha256,
        modelVersion ?? '',
        preprocessingVersion ?? '',
      ),
      /incompatible with the configured classifier/,
    );
  }
});

test('corrupt class mapping, input pins and research declarations are rejected despite matching copy digest', async (context) => {
  const mutations: [string, (artifact: Record<string, unknown>) => void][] = [
    [
      'unsupported schema',
      (artifact) => {
        artifact.schema_version = 2;
      },
    ],
    [
      'missing verdict',
      (artifact) => {
        delete artifact.verdict;
      },
    ],
    [
      'unapproved verdict',
      (artifact) => {
        artifact.verdict = 'FIT FOR COMMERCIAL DEPLOYMENT';
      },
    ],
    [
      'production promotion',
      (artifact) => {
        artifact.production_model_promoted = true;
      },
    ],
    [
      'unsupported architecture',
      (artifact) => {
        artifact.architecture = 'unapproved_architecture';
      },
    ],
    [
      'oversized model version',
      (artifact) => {
        artifact.model_version = 'm'.repeat(81);
      },
    ],
    [
      'empty experiment identity',
      (artifact) => {
        artifact.training_experiment_id = '';
      },
    ],
    [
      'invalid checkpoint digest',
      (artifact) => {
        object(artifact.checkpoint).sha256 = 'invalid';
      },
    ],
    [
      'oversized dataset version',
      (artifact) => {
        object(artifact.dataset).version = 'd'.repeat(121);
      },
    ],
    [
      'invalid dataset fingerprint',
      (artifact) => {
        object(artifact.dataset).manifest_fingerprint = 'invalid';
      },
    ],
    [
      'missing class',
      (artifact) => {
        artifact.classes = diseaseLabels.slice(0, 3).map((label, index) => ({ label, index }));
      },
    ],
    [
      'extra class',
      (artifact) => {
        artifact.classes = [...diseaseLabels, 'Unknown'].map((label, index) => ({ label, index }));
      },
    ],
    [
      'reordered class mapping',
      (artifact) => {
        artifact.classes = [...diseaseLabels].reverse().map((label, index) => ({ label, index }));
      },
    ],
    [
      'duplicate class',
      (artifact) => {
        artifact.classes = diseaseLabels.map((_label, index) => ({ label: 'Healthy', index }));
      },
    ],
    [
      'changed literal label',
      (artifact) => {
        artifact.classes = diseaseLabels.map((label, index) => ({
          label: label.toLowerCase(),
          index,
        }));
      },
    ],
    [
      'changed class index',
      (artifact) => {
        artifact.classes = diseaseLabels.map((label, index) => ({ label, index: index + 1 }));
      },
    ],
    [
      'inconsistent class dictionary',
      (artifact) => {
        object(artifact.class_to_index).Healthy = 0;
      },
    ],
    [
      'extra class dictionary entry',
      (artifact) => {
        object(artifact.class_to_index).Unknown = 4;
      },
    ],
    [
      'missing class dictionary entry',
      (artifact) => {
        delete object(artifact.class_to_index).Healthy;
      },
    ],
    [
      'incompatible image size',
      (artifact) => {
        object(artifact.input).shape = [1, 3, 256, 256];
      },
    ],
    [
      'incompatible color space',
      (artifact) => {
        object(artifact.input).color_space = 'BGR';
      },
    ],
    [
      'incompatible layout',
      (artifact) => {
        object(artifact.input).layout = 'NHWC';
      },
    ],
    [
      'incompatible dtype',
      (artifact) => {
        object(artifact.input).dtype = 'float64';
      },
    ],
    [
      'incompatible preprocessing version',
      (artifact) => {
        object(artifact.preprocessing).version = '2.0.0';
      },
    ],
    [
      'invalid preprocessing fingerprint',
      (artifact) => {
        object(artifact.preprocessing).semantic_sha256 = 'invalid';
      },
    ],
    [
      'unsupported extraction policy',
      (artifact) => {
        object(artifact.preprocessing).segmentation_policy = 'green-threshold-only';
      },
    ],
    [
      'enabled calibration',
      (artifact) => {
        object(artifact.calibration).enabled = true;
      },
    ],
    [
      'changed calibration method',
      (artifact) => {
        object(artifact.calibration).method = 'temperature';
      },
    ],
    [
      'changed calibration temperature',
      (artifact) => {
        object(artifact.calibration).temperature = 1.2;
      },
    ],
    [
      'invented certainty threshold',
      (artifact) => {
        object(artifact.calibration).operational_threshold = 0.9;
      },
    ],
    [
      'missing research policy',
      (artifact) => {
        delete artifact.research_policy;
      },
    ],
    [
      'commercial purpose',
      (artifact) => {
        object(artifact.research_policy).permitted_use = 'commercial deployment';
      },
    ],
    [
      'commercial clearance',
      (artifact) => {
        object(artifact.research_policy).commercial_clearance = true;
      },
    ],
    [
      'raw redistribution',
      (artifact) => {
        object(artifact.research_policy).raw_image_redistribution = true;
      },
    ],
  ];
  for (const [name, mutate] of mutations) {
    await context.test(name, async (subcontext) => {
      const artifact = await sourceMetadata();
      mutate(artifact);
      const fixture = await temporaryMetadata(subcontext, Buffer.from(JSON.stringify(artifact)));
      await assert.rejects(
        readApprovedModel(fixture.path, fixture.sha256, approvedModelVersion, '1.0.0'),
        /incompatible with the configured classifier/,
      );
    });
  }
  assert.equal(digest(await readFile(approvedMetadataPath)), approvedMetadataSha256);
});
