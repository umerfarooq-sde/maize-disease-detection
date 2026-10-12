import { randomUUID } from 'node:crypto';
import type { KnowledgeRepository } from '../../src/modules/knowledge/knowledge.repository.js';
import type {
  DiseaseSummary,
  KnowledgeClient,
  KnowledgeSearch,
  KnowledgeSource,
  RetrievalResult,
} from '../../src/modules/knowledge/knowledge.types.js';

export const source: KnowledgeSource = {
  url: 'https://extension.umn.edu/agriculture/crop-production/corn/common-rust-on-corn',
  title: 'Common rust on corn',
  publisher: 'University of Minnesota Extension',
  authors: ['Dean Malvick'],
  publishedAt: null,
  retrievedAt: '2026-10-12',
  rights: 'Synthetic test citation; no publisher text is reproduced.',
};
export const disease: DiseaseSummary = {
  slug: 'common-rust',
  name: 'Common Rust',
  scientificName: 'Puccinia sorghi',
  description: 'Synthetic disease description for contract testing.',
};

export function retrieval(): RetrievalResult {
  return {
    status: 'MATCHES',
    chunks: [
      {
        documentId: randomUUID(),
        documentKey: 'maize-common-rust-symptoms',
        documentVersion: 1,
        chunkId: randomUUID(),
        chunkIndex: 0,
        content: 'Synthetic common rust symptom evidence for contract testing.',
        title: 'Common Rust: symptoms',
        diseaseLabel: 'Common_Rust',
        knowledgeType: 'SYMPTOMS',
        source,
        similarity: 0.82,
        metadata: {
          curation: {
            region: 'United States',
            language: 'en',
            review: 'INTENTIONALLY_CURATED_AUTHORITATIVE',
          },
          corpusVersion: 'synthetic-corpus-v1',
          contentHash: 'a'.repeat(64),
          start: 0,
          end: 58,
        },
      },
    ],
    embeddingModel: 'gemini-embedding-001',
    embeddingVersion: 'synthetic-document-retrieval-v1',
    embeddingDimensions: 768,
    retrievalVersion: 'cosine-exact-v1',
    evidencePolicy: 'CANDIDATES_ONLY',
  };
}

export function memoryKnowledge() {
  const records = [
    {
      ...disease,
      status: 'ACTIVE',
      createdById: 'private-creator',
      knowledgeDocuments: [
        {
          id: randomUUID(),
          documentKey: 'maize-common-rust-symptoms',
          version: 1,
          title: 'Common Rust: symptoms',
          content: 'Synthetic current evidence.',
          knowledgeType: 'SYMPTOMS' as const,
          status: 'ACTIVE',
          metadata: { source, secret: 'private-metadata' },
        },
        {
          id: randomUUID(),
          documentKey: 'maize-common-rust-symptoms',
          version: 2,
          title: 'Draft',
          content: 'private-draft',
          knowledgeType: 'SYMPTOMS' as const,
          status: 'DRAFT',
          metadata: { source },
        },
        {
          id: randomUUID(),
          documentKey: 'maize-common-rust-old',
          version: 1,
          title: 'Archived',
          content: 'private-archive',
          knowledgeType: 'SYMPTOMS' as const,
          status: 'ARCHIVED',
          metadata: { source },
        },
        {
          id: randomUUID(),
          documentKey: 'legacy-source-missing',
          version: 1,
          title: 'Unreviewed',
          content: 'private-unattributed',
          knowledgeType: 'CAUSES' as const,
          status: 'ACTIVE',
          metadata: { secret: 'private-no-source' },
        },
      ],
    },
    {
      ...disease,
      slug: 'inactive-disease',
      status: 'INACTIVE',
      createdById: 'private-creator',
      knowledgeDocuments: [],
    },
    {
      ...disease,
      slug: 'draft-disease',
      status: 'DRAFT',
      createdById: 'private-creator',
      knowledgeDocuments: [],
    },
    {
      slug: 'healthy',
      name: 'Healthy / scouting context',
      scientificName: null,
      description: 'Synthetic scouting context.',
      status: 'ACTIVE',
      createdById: 'private-creator',
      knowledgeDocuments: [],
    },
  ];
  const repository: KnowledgeRepository = {
    async listDiseases() {
      return records.filter((record) => record.status === 'ACTIVE');
    },
    async findDisease(slug) {
      const record = records.find((entry) => entry.slug === slug && entry.status === 'ACTIVE');
      return record
        ? {
            ...record,
            knowledgeDocuments: record.knowledgeDocuments.filter((doc) => doc.status === 'ACTIVE'),
          }
        : null;
    },
  };
  const searches: KnowledgeSearch[] = [];
  const result = retrieval();
  const client: KnowledgeClient = {
    enabled: true,
    async search(input) {
      searches.push(input);
      return result;
    },
  };
  return { repository, records, client, searches, result };
}
