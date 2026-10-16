import { z } from 'zod';
import { diseaseLabels } from '../inference/inference.types.js';

export const knowledgeTypes = [
  'OVERVIEW',
  'SYMPTOMS',
  'CAUSES',
  'CONDITIONS',
  'MANAGEMENT',
  'PREVENTION',
  'REFERENCES',
] as const;

const identifier = z
  .string()
  .min(1)
  .max(160)
  .regex(/^[A-Za-z0-9][A-Za-z0-9._:/@-]*$/);
export const knowledgeSourceSchema = z.strictObject({
  url: z
    .string()
    .max(2048)
    .refine((value) => {
      try {
        const url = new URL(value);
        return url.protocol === 'https:' && !url.username && !url.password;
      } catch {
        return false;
      }
    }),
  title: z.string().min(1).max(255),
  publisher: z.string().min(1).max(255),
  authors: z.array(z.string().min(1).max(160)).max(16),
  publishedAt: z.iso.date().nullable(),
  retrievedAt: z.iso.date(),
  rights: z.string().min(1).max(1600),
});

// Keep only reviewed/public provenance. Provider/database metadata is never
// forwarded wholesale, even when a future service adds private fields.
const publicMetadataSchema = z
  .object({
    curation: z
      .object({
        region: z.string().max(255).optional(),
        language: z.string().max(16).optional(),
        review: z.string().max(120).optional(),
        sourceReviewedAt: z.string().max(32).optional(),
        sourceSection: z.string().max(600).optional(),
        scope: z.string().max(160).optional(),
      })
      .optional(),
    corpusVersion: identifier.optional(),
    contentHash: z
      .string()
      .regex(/^[a-f0-9]{64}$/)
      .optional(),
    start: z.number().int().min(0).max(10_000_000).optional(),
    end: z.number().int().min(0).max(10_000_000).optional(),
  })
  .refine(
    (value) => value.start === undefined || value.end === undefined || value.end >= value.start,
  );

export const knowledgeSearchSchema = z.strictObject({
  query: z
    .string()
    .transform((value) => value.replace(/^[\s\u0085]+|[\s\u0085]+$/gu, ''))
    .refine((value) => {
      // Match the internal Python query contract: Unicode code points, readable
      // text and the provider byte budget, rather than JavaScript UTF-16 units.
      const characters = Array.from(value);
      const length = characters.length;
      return (
        length >= 3 &&
        length <= 1000 &&
        Buffer.byteLength(value, 'utf8') <= 1800 &&
        !characters.some(
          (char) => (char.codePointAt(0) ?? 0) < 32 && char !== '\n' && char !== '\t',
        ) &&
        Buffer.from(value, 'utf8').toString('utf8') === value
      );
    }),
  diseaseLabel: z.enum(diseaseLabels).optional(),
  knowledgeType: z.enum(knowledgeTypes).optional(),
  documentVersion: z.number().int().min(1).max(2_147_483_647).optional(),
  topK: z.number().int().min(1).max(10).default(3),
});

const knowledgeChunkSchema = z.strictObject({
  documentId: z.uuid(),
  documentKey: z
    .string()
    .min(1)
    .max(160)
    .regex(/^[a-z0-9][a-z0-9._-]*$/),
  documentVersion: z.number().int().min(1).max(2_147_483_647),
  chunkId: z.uuid(),
  chunkIndex: z.number().int().min(0).max(1_000_000),
  content: z.string().min(1).max(12_000),
  title: z.string().min(1).max(255),
  diseaseLabel: z.enum(diseaseLabels),
  knowledgeType: z.enum(knowledgeTypes),
  source: knowledgeSourceSchema,
  similarity: z.number().finite().min(-1).max(1),
  metadata: publicMetadataSchema,
});

export const retrievalResultSchema = z
  .strictObject({
    status: z.enum(['MATCHES', 'NO_MATCHES']),
    chunks: z.array(knowledgeChunkSchema).max(10),
    embeddingModel: identifier,
    embeddingVersion: identifier,
    embeddingDimensions: z.number().int().min(128).max(3072),
    retrievalVersion: z.literal('cosine-exact-v1'),
    evidencePolicy: z.literal('CANDIDATES_ONLY'),
  })
  .refine((value) => {
    if ((value.status === 'NO_MATCHES') !== (value.chunks.length === 0)) return false;
    if (new Set(value.chunks.map((chunk) => chunk.chunkId)).size !== value.chunks.length)
      return false;
    if (
      new Set(value.chunks.map((chunk) => `${chunk.documentId}:${chunk.chunkIndex}`)).size !==
      value.chunks.length
    )
      return false;
    for (let index = 1; index < value.chunks.length; index++) {
      const previous = value.chunks[index - 1];
      const current = value.chunks[index];
      if (!previous || !current || current.similarity > previous.similarity + 1e-12) return false;
    }
    return true;
  });

export type KnowledgeSearch = z.infer<typeof knowledgeSearchSchema>;
export type RetrievalResult = z.infer<typeof retrievalResultSchema>;
export type KnowledgeSource = z.infer<typeof knowledgeSourceSchema>;
export interface KnowledgeClient {
  readonly enabled: boolean;
  search(input: KnowledgeSearch): Promise<RetrievalResult>;
}
export interface DiseaseSummary {
  slug: string;
  name: string;
  scientificName: string | null;
  description: string;
}
export interface DiseaseDetail extends DiseaseSummary {
  catalogue?: { classifierSupported: boolean; literalLabel: string | null; applicability: unknown };
  sections: {
    documentId: string;
    documentKey: string;
    documentVersion: number;
    knowledgeType: (typeof knowledgeTypes)[number];
    title: string;
    content: string;
    source: KnowledgeSource;
  }[];
}
