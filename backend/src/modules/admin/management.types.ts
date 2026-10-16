import { createHash } from 'node:crypto';
import { z } from 'zod';
import { diseaseLabels } from '../inference/inference.types.js';
import { knowledgeSourceSchema, knowledgeTypes } from '../knowledge/knowledge.types.js';

export const supportedDiseases = diseaseLabels.map((label) => ({
  label,
  slug: label.toLowerCase().replaceAll('_', '-'),
}));
export const managedSlug = z
  .string()
  .max(120)
  .regex(/^[a-z0-9]+(?:-[a-z0-9]+)*$/);
export const managementText = (maximum: number) =>
  z
    .string()
    .trim()
    .min(1)
    .max(maximum)
    .refine((value) => Buffer.from(value, 'utf8').toString('utf8') === value)
    .refine(
      (value) =>
        !Array.from(value).some((char) => {
          const code = char.codePointAt(0) ?? 0;
          return (code < 32 && code !== 9 && code !== 10 && code !== 13) || code === 127;
        }),
    );
export const sourceSchema = knowledgeSourceSchema.extend({
  url: knowledgeSourceSchema.shape.url
    .transform((value) => new URL(value).href)
    .pipe(z.string().max(2048)),
  title: managementText(255),
  publisher: managementText(255),
  authors: z.array(managementText(160)).max(16),
  publishedAt: z.iso
    .date()
    .refine((value) => value >= '0001-01-01')
    .nullable(),
  retrievedAt: z.iso.date().refine((value) => value >= '0001-01-01'),
  rights: managementText(1000),
});
export const curationSchema = z.strictObject({
  review: z.literal('INTENTIONALLY_CURATED_AUTHORITATIVE'),
  language: z.literal('en'),
  region: managementText(255),
  sourceSection: managementText(600),
});
export const draftDocumentSchema = z.strictObject({
  documentKey: z
    .string()
    .max(100)
    .regex(/^[a-z0-9][a-z0-9._-]*$/),
  expectedVersion: z.number().int().min(0).max(2147483646),
  diseaseSlug: managedSlug.refine((value) => supportedDiseases.some((item) => item.slug === value)),
  knowledgeType: z.enum(knowledgeTypes),
  title: managementText(255),
  content: managementText(4000),
  source: sourceSchema,
  region: managementText(255),
  sourceSection: managementText(600),
  reviewNote: managementText(2000).refine((value) => value.length >= 20),
  approved: z.literal(true),
});
export type DraftDocument = z.infer<typeof draftDocumentSchema>;
export const catalogueMetadataSchema = z
  .strictObject({
    growthStages: z.array(managementText(160)).max(12),
    severityDescriptors: z.array(managementText(600)).max(8),
    source: sourceSchema.nullable(),
    reviewNote: managementText(2000).min(20),
    approved: z.literal(true),
  })
  .refine(
    (value) =>
      value.source !== null ||
      (value.growthStages.length === 0 && value.severityDescriptors.length === 0),
  );
export const diseaseEditSchema = z.strictObject({
  name: managementText(160),
  scientificName: managementText(200).nullable(),
  description: managementText(2000),
  status: z.enum(['ACTIVE', 'INACTIVE']),
  expectedRevision: z.string().regex(/^[a-f0-9]{64}$/),
  catalogueMetadata: catalogueMetadataSchema.optional(),
});
export type DiseaseEdit = z.infer<typeof diseaseEditSchema>;
export const diseaseCreateSchema = diseaseEditSchema.omit({ expectedRevision: true }).extend({
  slug: managedSlug.refine((value) => !supportedDiseases.some((item) => item.slug === value)),
  source: sourceSchema,
  reviewNote: managementText(2000).min(20),
  approved: z.literal(true),
});
export type DiseaseCreate = z.infer<typeof diseaseCreateSchema>;
export const preparedDocumentSchema = z.strictObject({
  content: managementText(4000),
  contentHash: z.string().regex(/^[a-f0-9]{64}$/),
  metadata: z.strictObject({
    source: sourceSchema,
    curation: curationSchema,
    literalLabel: z.enum(diseaseLabels),
    corpusVersion: z.string().min(1).max(160),
    retrievalIdentity: z.string().regex(/^[a-f0-9]{64}$/),
    chunking: z.strictObject({
      version: z.string().min(1).max(80),
      size: z.number().int().min(200).max(1500),
      overlap: z.number().int().min(0).max(300),
    }),
    embedding: z.strictObject({
      provider: z.literal('google'),
      model: z.string().min(1).max(160),
      version: z.string().min(1).max(160),
      dimensions: z.number().int().min(1).max(3072),
      normalization: z.literal('l2'),
      api: z.string().min(1).max(80),
    }),
  }),
});
export type PreparedDocument = z.infer<typeof preparedDocumentSchema>;
export const indexReceiptSchema = z.strictObject({
  documentId: z.uuid(),
  contentHash: z.string().regex(/^[a-f0-9]{64}$/),
  retrievalIdentity: z.string().regex(/^[a-f0-9]{64}$/),
  chunkCount: z.number().int().min(1).max(32),
  ready: z.boolean(),
});
export type IndexReceipt = z.infer<typeof indexReceiptSchema>;
export interface ManagementIndexer {
  prepare(document: Record<string, unknown>): Promise<PreparedDocument>;
  index(id: string, actorId: string, requestId: string, checkOnly: boolean): Promise<IndexReceipt>;
}
export const hashContent = (content: string) =>
  createHash('sha256').update(content, 'utf8').digest('hex');
export const diseaseRevision = (row: {
  name: string;
  scientificName: string | null;
  description: string;
  status: string;
  updatedAt: Date;
  catalogueMetadata?: unknown;
}) =>
  hashContent(
    JSON.stringify([
      row.name,
      row.scientificName,
      row.description,
      row.status,
      row.updatedAt.toISOString(),
      row.catalogueMetadata ?? null,
    ]),
  );
