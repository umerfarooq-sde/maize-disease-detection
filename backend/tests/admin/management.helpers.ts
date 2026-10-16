import { randomUUID } from 'node:crypto';
import type {
  ManagedDisease,
  ManagedDocument,
  ManagementRepository,
} from '../../src/modules/admin/management.repository.js';
import {
  draftDocumentSchema,
  hashContent,
  type ManagementIndexer,
  type PreparedDocument,
} from '../../src/modules/admin/management.types.js';

export function knowledgeDraft() {
  return draftDocumentSchema.parse({
    documentKey: 'synthetic-reviewed-note',
    expectedVersion: 0,
    diseaseSlug: 'common-rust',
    knowledgeType: 'OVERVIEW',
    title: 'Synthetic fixture',
    content: 'Synthetic source-backed revision for contract testing only.',
    region: 'Synthetic scope',
    sourceSection: 'Fixture section',
    reviewNote: 'Synthetic source and applicability review for an isolated test.',
    approved: true,
    source: {
      url: 'https://example.invalid/source',
      title: 'Synthetic source',
      publisher: 'Synthetic publisher',
      authors: [],
      publishedAt: null,
      retrievedAt: '2026-10-01',
      rights: 'Synthetic test-only source; no agronomic recommendation.',
    },
  });
}
export function memoryManagement() {
  const date = new Date('2026-10-01T00:00:00Z');
  const disease: ManagedDisease = {
    id: randomUUID(),
    slug: 'common-rust',
    name: 'Synthetic disease display',
    scientificName: null,
    description: 'Synthetic display metadata',
    status: 'ACTIVE',
    severity: null,
    symptoms: [],
    causes: [],
    treatments: [],
    precautions: [],
    favorableConditions: [],
    affectedGrowthStages: [],
    createdAt: date,
    updatedAt: date,
  };
  const rows: ManagedDocument[] = [];
  const writes: unknown[] = [];
  let fail = false;
  const repository: ManagementRepository = {
    async createDisease() {
      return disease;
    },
    async diseases() {
      return [disease];
    },
    async editDisease(_slug, input, actor, request) {
      writes.push({ input, actor, request });
      return disease;
    },
    async documents() {
      return { items: rows, nextCursor: null };
    },
    async document(id) {
      const row = rows.find((item) => item.id === id);
      if (!row) throw new Error('Missing synthetic row');
      return row;
    },
    async latest(key) {
      return rows.filter((item) => item.documentKey === key).at(-1) ?? null;
    },
    async createDraft(input, prepared, actor, request) {
      writes.push({ actor, request, input });
      const row: ManagedDocument = {
        id: randomUUID(),
        documentKey: input.documentKey,
        version: input.expectedVersion + 1,
        title: input.title,
        content: prepared.content,
        contentHash: prepared.contentHash,
        sourceReference: input.source.url,
        metadata: prepared.metadata,
        topic: 'DISEASE',
        language: 'en',
        status: 'DRAFT',
        diseaseId: disease.id,
        fertilizerId: null,
        createdById: actor,
        knowledgeType: input.knowledgeType,
        createdAt: date,
        updatedAt: date,
        disease: { slug: disease.slug },
        chunks: [],
      };
      rows.push(row);
      return row;
    },
    async changeStatus(id, status, expected, receipt, actor, request) {
      writes.push({ id, status, expected, receipt, actor, request });
      const row = rows.find((item) => item.id === id);
      if (!row) throw new Error('Missing fixture');
      row.status = status;
      return row;
    },
  };
  const indexer: ManagementIndexer = {
    async prepare(input) {
      if (fail) throw new Error('Synthetic indexing failure');
      return {
        content: input['content'] as string,
        contentHash: hashContent(input['content'] as string),
        metadata: {
          source: input['source'],
          curation: input['metadata'],
          literalLabel: input['diseaseLabel'],
          corpusVersion: `admin-${input['documentKey']}-v${input['version']}`,
          retrievalIdentity: 'a'.repeat(64),
          chunking: { version: 'fixture', size: 1000, overlap: 120 },
          embedding: {
            provider: 'google',
            model: 'fixture-model',
            version: 'fixture-v1',
            dimensions: 128,
            normalization: 'l2',
            api: 'fixture',
          },
        },
      } as PreparedDocument;
    },
    async index(id) {
      if (fail) throw new Error('Synthetic provider failure');
      const row = rows.find((item) => item.id === id);
      return {
        documentId: id,
        contentHash: row?.contentHash ?? '0'.repeat(64),
        retrievalIdentity: 'a'.repeat(64),
        ready: true,
        chunkCount: 1,
      };
    },
  };
  return {
    repository,
    indexer,
    rows,
    writes,
    disease,
    setFail(value: boolean) {
      fail = value;
    },
  };
}
