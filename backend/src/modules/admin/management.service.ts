import { AppError } from '../../errors/app-error.js';
import { sameJson } from '../../utils/json-equality.js';
import type { ManagedDocument, ManagementRepository } from './management.repository.js';
import {
  type DraftDocument,
  type DiseaseEdit,
  type DiseaseCreate,
  type ManagementIndexer,
  diseaseRevision,
  hashContent,
  supportedDiseases,
} from './management.types.js';

function documentSummary(row: ManagedDocument) {
  return {
    id: row.id,
    documentKey: row.documentKey,
    version: row.version,
    title: row.title,
    status: row.status,
    diseaseSlug: row.disease?.slug,
    knowledgeType: row.knowledgeType,
    createdAt: row.createdAt.toISOString(),
    updatedAt: row.updatedAt.toISOString(),
    indexed:
      row.chunks.length > 0 && row.chunks.every((chunk) => chunk.embeddingStatus === 'READY'),
  };
}
export function createManagementService(
  repository: ManagementRepository,
  indexer: ManagementIndexer,
  now: () => Date = () => new Date(),
) {
  return {
    async diseases() {
      return {
        items: (await repository.diseases()).map((row) => ({
          id: row.id,
          slug: row.slug,
          literalLabel: supportedDiseases.find((item) => item.slug === row.slug)?.label ?? null,
          classifierSupported: supportedDiseases.some((item) => item.slug === row.slug),
          catalogueMetadata: row.catalogueMetadata ?? null,
          name: row.name,
          description: row.description,
          scientificName: row.scientificName,
          status: row.status,
          revision: diseaseRevision(row),
          createdAt: row.createdAt.toISOString(),
          updatedAt: row.updatedAt.toISOString(),
        })),
        classMappingEditable: false,
      };
    },
    async editDisease(slug: string, input: DiseaseEdit, actor: string, requestId: string) {
      await repository.editDisease(slug, input, actor, requestId);
      return this.diseases();
    },
    async createDisease(input: DiseaseCreate, actor: string, requestId: string) {
      await repository.createDisease(input, actor, requestId);
      return this.diseases();
    },
    async documents(cursor?: string) {
      const page = await repository.documents(cursor);
      return { items: page.items.map(documentSummary), nextCursor: page.nextCursor };
    },
    async document(id: string) {
      const row = await repository.document(id);
      const metadata = row.metadata;
      const object =
        metadata && typeof metadata === 'object' && !Array.isArray(metadata) ? metadata : {};
      return {
        ...documentSummary(row),
        content: row.content,
        source: object.source ?? null,
        curation: object.curation ?? null,
      };
    },
    async createDraft(input: DraftDocument, actor: string, requestId: string) {
      const previous = await repository.latest(input.documentKey);
      if (
        (previous?.version ?? 0) !== input.expectedVersion ||
        (previous &&
          (previous.disease?.slug !== input.diseaseSlug ||
            previous.knowledgeType !== input.knowledgeType))
      )
        throw new AppError('CONFLICT');
      const label = supportedDiseases.find((item) => item.slug === input.diseaseSlug)?.label;
      if (!label) throw new AppError('VALIDATION_ERROR');
      const curation = {
        review: 'INTENTIONALLY_CURATED_AUTHORITATIVE',
        language: 'en',
        region: input.region,
        sourceSection: input.sourceSection,
      };
      const descriptor = {
        documentKey: input.documentKey,
        version: input.expectedVersion + 1,
        diseaseLabel: label,
        title: input.title,
        knowledgeType: input.knowledgeType,
        content: input.content,
        source: input.source,
        metadata: curation,
      };
      if (Buffer.byteLength(JSON.stringify(descriptor), 'utf8') > 32768)
        throw new AppError('VALIDATION_ERROR');
      const prepared = await indexer.prepare(descriptor);
      if (
        prepared.contentHash !== hashContent(prepared.content) ||
        prepared.metadata.literalLabel !== label ||
        !sameJson(prepared.metadata.source, input.source) ||
        !sameJson(prepared.metadata.curation, curation) ||
        prepared.metadata.corpusVersion !==
          `admin-${input.documentKey}-v${input.expectedVersion + 1}`
      )
        throw new AppError('KNOWLEDGE_INVALID_RESPONSE');
      return documentSummary(
        await repository.createDraft(input, prepared, actor, requestId, now().toISOString()),
      );
    },
    async index(id: string, actor: string, requestId: string) {
      const row = await repository.document(id);
      if (row.status !== 'DRAFT') throw new AppError('CONFLICT');
      const receipt = await indexer.index(id, actor, requestId, false);
      const metadata = row.metadata;
      if (
        !receipt.ready ||
        receipt.documentId !== id ||
        receipt.contentHash !== row.contentHash ||
        !metadata ||
        typeof metadata !== 'object' ||
        Array.isArray(metadata) ||
        metadata.retrievalIdentity !== receipt.retrievalIdentity
      )
        throw new AppError('KNOWLEDGE_INVALID_RESPONSE');
      return receipt;
    },
    async changeStatus(
      id: string,
      status: 'ACTIVE' | 'ARCHIVED',
      expectedStatus: 'ACTIVE' | 'ARCHIVED' | 'DRAFT',
      actor: string,
      requestId: string,
    ) {
      const receipt = status === 'ACTIVE' ? await indexer.index(id, actor, requestId, true) : null;
      return documentSummary(
        await repository.changeStatus(id, status, expectedStatus, receipt, actor, requestId),
      );
    },
  };
}
export type ManagementService = ReturnType<typeof createManagementService>;
