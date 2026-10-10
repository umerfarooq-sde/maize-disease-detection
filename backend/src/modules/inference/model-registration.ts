import { createHash } from 'node:crypto';
import { readFile } from 'node:fs/promises';
import { z } from 'zod';
import { diseaseLabels } from './inference.types.js';

const hash = z.string().regex(/^[a-f0-9]{64}$/);
const artifactSchema = z
  .object({
    schema_version: z.literal(1),
    model_version: z.string().min(1).max(80),
    architecture: z.literal('mobilenet_v3_small'),
    training_experiment_id: z.string().min(1),
    verdict: z.literal('FIT WITH DOCUMENTED LIMITATIONS'),
    production_model_promoted: z.literal(false),
    checkpoint: z.object({ sha256: hash }),
    classes: z.array(z.object({ label: z.enum(diseaseLabels), index: z.number().int() })).length(4),
    class_to_index: z.record(z.string(), z.number().int()),
    dataset: z.object({ version: z.string().min(1).max(120), manifest_fingerprint: hash }),
    input: z.object({
      shape: z.tuple([z.literal(1), z.literal(3), z.literal(224), z.literal(224)]),
      color_space: z.literal('RGB'),
      layout: z.literal('NCHW'),
      dtype: z.literal('float32'),
    }),
    preprocessing: z.object({
      version: z.literal('1.0.0'),
      semantic_sha256: hash,
      segmentation_policy: z.literal('disabled; full oriented frame retained'),
      configuration: z.record(z.string(), z.json()),
    }),
    calibration: z.object({
      enabled: z.literal(false),
      method: z.literal('none'),
      temperature: z.literal(1),
      operational_threshold: z.null(),
    }),
    training: z.object({ seed: z.number().int(), hyperparameters: z.record(z.string(), z.json()) }),
    research_policy: z.object({
      permitted_use: z.literal('non-commercial academic/FYP research only'),
      commercial_clearance: z.literal(false),
      raw_image_redistribution: z.literal(false),
    }),
  })
  .refine(
    (value) =>
      diseaseLabels.every(
        (label, index) =>
          value.classes[index]?.label === label &&
          value.classes[index]?.index === index &&
          value.class_to_index[label] === index,
      ) && Object.keys(value.class_to_index).length === 4,
  );

export async function readApprovedModel(
  path: string,
  expectedHash: string,
  modelVersion: string,
  preprocessingVersion: string,
) {
  // Only an operator-supplied pinned metadata file is read; no model URLs/downloads.
  const bytes = await readFile(path);
  if (
    !/^[a-f0-9]{64}$/.test(expectedHash) ||
    bytes.length > 512 * 1024 ||
    createHash('sha256').update(bytes).digest('hex') !== expectedHash
  )
    throw new Error('Model metadata integrity check failed.');
  const parsed = artifactSchema.safeParse(JSON.parse(bytes.toString('utf8')) as unknown);
  if (
    !parsed.success ||
    parsed.data.model_version !== modelVersion ||
    parsed.data.preprocessing.version !== preprocessingVersion
  )
    throw new Error('Model metadata is incompatible with the configured classifier.');
  const artifact = parsed.data;
  return {
    version: artifact.model_version,
    architecture: artifact.architecture,
    artifactUri: `sha256:${artifact.checkpoint.sha256}`,
    artifactSha256: artifact.checkpoint.sha256,
    datasetVersion: artifact.dataset.version,
    preprocessingVersion: artifact.preprocessing.version,
    classLabels: [...diseaseLabels],
    status: 'VALIDATED' as const,
    trainingConfig: {
      metadataSha256: expectedHash,
      experimentId: artifact.training_experiment_id,
      seed: artifact.training.seed,
      hyperparameters: artifact.training.hyperparameters,
      preprocessingHash: artifact.preprocessing.semantic_sha256,
      preprocessing: artifact.preprocessing.configuration,
      manifestFingerprint: artifact.dataset.manifest_fingerprint,
      researchPolicy: artifact.research_policy,
    },
  };
}
export type ApprovedModel = Awaited<ReturnType<typeof readApprovedModel>>;
