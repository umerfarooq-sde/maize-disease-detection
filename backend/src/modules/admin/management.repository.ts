import { Prisma, type PrismaClient } from '../../generated/prisma/client.js';
import { AppError } from '../../errors/app-error.js';
import {
  type DiseaseEdit,
  type DiseaseCreate,
  type DraftDocument,
  type PreparedDocument,
  type IndexReceipt,
  diseaseRevision,
  supportedDiseases,
} from './management.types.js';

const diseaseInclude = {
  disease: { select: { slug: true } },
  chunks: { select: { embeddingStatus: true }, take: 33 },
} satisfies Prisma.KnowledgeDocumentInclude;
export type ManagedDocument = Prisma.KnowledgeDocumentGetPayload<{
  include: typeof diseaseInclude;
}>;
export type ManagedDisease = Omit<
  Prisma.DiseaseGetPayload<Record<string, never>>,
  'catalogueMetadata'
> & { catalogueMetadata?: Prisma.JsonValue };
export interface ManagementRepository {
  diseases(): Promise<ManagedDisease[]>;
  createDisease(input: DiseaseCreate, actorId: string, requestId: string): Promise<ManagedDisease>;
  editDisease(
    slug: string,
    input: DiseaseEdit,
    actorId: string,
    requestId: string,
  ): Promise<ManagedDisease>;
  documents(cursor?: string): Promise<{ items: ManagedDocument[]; nextCursor: string | null }>;
  document(id: string): Promise<ManagedDocument>;
  latest(key: string): Promise<ManagedDocument | null>;
  createDraft(
    input: DraftDocument,
    prepared: PreparedDocument,
    actorId: string,
    requestId: string,
    reviewedAt: string,
  ): Promise<ManagedDocument>;
  changeStatus(
    id: string,
    status: 'ACTIVE' | 'ARCHIVED',
    expectedStatus: 'ACTIVE' | 'ARCHIVED' | 'DRAFT',
    receipt: IndexReceipt | null,
    actorId: string,
    requestId: string,
  ): Promise<ManagedDocument>;
}
export function createManagementRepository(database: PrismaClient): ManagementRepository {
  async function locked<T>(action: (tx: Prisma.TransactionClient) => Promise<T>): Promise<T> {
    try {
      return await database.$transaction(
        async (tx) => {
          await tx.$executeRaw`SELECT pg_advisory_xact_lock(hashtextextended('maizedoctor-knowledge-ingestion-v1',0))`;
          return action(tx);
        },
        { maxWait: 10000, timeout: 15000 },
      );
    } catch (error) {
      if (
        error instanceof Prisma.PrismaClientKnownRequestError &&
        ['P2002', 'P2034'].includes(error.code)
      )
        throw new AppError('CONFLICT');
      throw error;
    }
  }
  async function retireSource(
    tx: Prisma.TransactionClient,
    record: ManagedDocument,
    actorId: string,
    requestId: string,
  ) {
    const metadata = record.metadata;
    if (
      metadata &&
      typeof metadata === 'object' &&
      !Array.isArray(metadata) &&
      typeof metadata.sourceRecordId === 'string' &&
      record.diseaseId !== null
    ) {
      const changed = await tx.diseaseSource.updateMany({
        where: { id: metadata.sourceRecordId, diseaseId: record.diseaseId },
        data: { status: 'INACTIVE' },
      });
      if (changed.count)
        await tx.auditLog.create({
          data: {
            actorId,
            requestId,
            action: 'DEACTIVATE',
            entityType: 'disease_source',
            entityId: metadata.sourceRecordId,
            changes: { status: 'INACTIVE', documentId: record.id },
          },
        });
    }
  }
  return {
    diseases() {
      return database.disease.findMany({
        orderBy: { slug: 'asc' },
        take: 100,
      });
    },
    createDisease(input, actorId, requestId) {
      return locked(async (tx) => {
        const { source, reviewNote, approved: _, ...fields } = input;
        const row = await tx.disease.create({
          data: {
            ...fields,
            catalogueMetadata: {
              growthStages: [],
              severityDescriptors: [],
              ...fields.catalogueMetadata,
              source,
              reviewNote,
              approved: true,
              reviewedAt: new Date().toISOString(),
              classifierSupported: false,
            },
          },
        });
        await tx.auditLog.create({
          data: {
            actorId,
            requestId,
            action: 'CREATE',
            entityType: 'disease',
            entityId: row.id,
            changes: { slug: row.slug, classifierSupported: false, source },
          },
        });
        return row;
      });
    },
    editDisease(slug, input, actorId, requestId) {
      return locked(async (tx) => {
        const row = await tx.disease.findUnique({ where: { slug } });
        if (!row) throw new AppError('NOT_FOUND');
        if (diseaseRevision(row) !== input.expectedRevision) throw new AppError('CONFLICT');
        const { expectedRevision: _, catalogueMetadata, ...changes } = input;
        const updated = await tx.disease.update({
          where: { id: row.id },
          data: {
            ...changes,
            ...(catalogueMetadata
              ? {
                  affectedGrowthStages: catalogueMetadata.growthStages,
                  catalogueMetadata: { ...catalogueMetadata, reviewedAt: new Date().toISOString() },
                }
              : {}),
          },
        });
        await tx.auditLog.create({
          data: {
            actorId,
            requestId,
            action: 'UPDATE',
            entityType: 'disease',
            entityId: row.id,
            changes: {
              previousRevision: input.expectedRevision,
              revision: diseaseRevision(updated),
              fields: { ...changes, ...(catalogueMetadata ? { catalogueMetadata } : {}) },
              previousMetadata: row.catalogueMetadata,
            },
          },
        });
        return updated;
      });
    },
    async documents(cursor) {
      if (
        cursor &&
        !(await database.knowledgeDocument.findUnique({
          where: { id: cursor },
          select: { id: true },
        }))
      )
        throw new AppError('NOT_FOUND');
      const rows = await database.knowledgeDocument.findMany({
        where: {
          topic: 'DISEASE',
          language: 'en',
          disease: { slug: { in: supportedDiseases.map((item) => item.slug) } },
        },
        orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
        take: 51,
        ...(cursor ? { cursor: { id: cursor }, skip: 1 } : {}),
        include: diseaseInclude,
      });
      const items = rows.slice(0, 50);
      return { items, nextCursor: rows.length > 50 ? (items.at(-1)?.id ?? null) : null };
    },
    async document(id) {
      const row = await database.knowledgeDocument.findUnique({
        where: { id },
        include: diseaseInclude,
      });
      if (
        row?.topic !== 'DISEASE' ||
        row.language !== 'en' ||
        !supportedDiseases.some((item) => item.slug === row.disease?.slug)
      )
        throw new AppError('NOT_FOUND');
      return row;
    },
    latest(documentKey) {
      return database.knowledgeDocument.findFirst({
        where: { documentKey },
        orderBy: { version: 'desc' },
        include: diseaseInclude,
      });
    },
    createDraft(input, prepared, actorId, requestId, reviewedAt) {
      return locked(async (tx) => {
        const disease = await tx.disease.findUnique({ where: { slug: input.diseaseSlug } });
        if (!disease) throw new AppError('NOT_FOUND');
        const previous = await tx.knowledgeDocument.findFirst({
          where: { documentKey: input.documentKey },
          orderBy: { version: 'desc' },
        });
        if (
          (previous?.version ?? 0) !== input.expectedVersion ||
          (previous &&
            (previous.diseaseId !== disease.id || previous.knowledgeType !== input.knowledgeType))
        )
          throw new AppError('CONFLICT');
        const source = await tx.diseaseSource.create({
          data: {
            diseaseId: disease.id,
            title: input.source.title,
            url: input.source.url,
            citation: input.source.rights,
            publisher: input.source.publisher,
            publishedAt: input.source.publishedAt ? new Date(input.source.publishedAt) : null,
            status: 'DRAFT',
          },
        });
        const document = await tx.knowledgeDocument.create({
          data: {
            documentKey: input.documentKey,
            version: input.expectedVersion + 1,
            title: input.title,
            content: prepared.content,
            contentHash: prepared.contentHash,
            sourceReference: input.source.url,
            topic: 'DISEASE',
            language: 'en',
            status: 'DRAFT',
            diseaseId: disease.id,
            knowledgeType: input.knowledgeType,
            createdById: actorId,
            metadata: {
              ...prepared.metadata,
              sourceRecordId: source.id,
              adminReview: {
                status: 'PROJECT_APPROVED_SOURCE',
                reviewedAt,
                reviewedBy: actorId,
                note: input.reviewNote,
              },
            },
          },
          include: diseaseInclude,
        });
        for (const [entityType, entityId, changes] of [
          [
            'knowledge_document',
            document.id,
            {
              documentKey: document.documentKey,
              version: document.version,
              status: 'DRAFT',
              sourceRecordId: source.id,
            },
          ],
          ['disease_source', source.id, { documentId: document.id, status: 'DRAFT' }],
        ] as const) {
          await tx.auditLog.create({
            data: { actorId, requestId, action: 'CREATE', entityType, entityId, changes },
          });
        }
        return document;
      });
    },
    changeStatus(id, status, expectedStatus, receipt, actorId, requestId) {
      return locked(async (tx) => {
        const row = await tx.knowledgeDocument.findUnique({
          where: { id },
          include: diseaseInclude,
        });
        if (
          row?.topic !== 'DISEASE' ||
          row.language !== 'en' ||
          !supportedDiseases.some((item) => item.slug === row.disease?.slug) ||
          row.diseaseId === null
        )
          throw new AppError('NOT_FOUND');
        if (row.status !== expectedStatus) throw new AppError('CONFLICT');
        const metadata = row.metadata;
        if (status === 'ACTIVE') {
          const disease = await tx.disease.findUnique({ where: { id: row.diseaseId } });
          const latest = await tx.knowledgeDocument.findFirst({
            where: { documentKey: row.documentKey },
            orderBy: { version: 'desc' },
            select: { id: true },
          });
          if (
            row.status !== 'DRAFT' ||
            latest?.id !== id ||
            disease?.status !== 'ACTIVE' ||
            !receipt?.ready ||
            receipt.documentId !== id ||
            receipt.contentHash !== row.contentHash ||
            !metadata ||
            typeof metadata !== 'object' ||
            Array.isArray(metadata) ||
            metadata.retrievalIdentity !== receipt.retrievalIdentity ||
            row.chunks.length !== receipt.chunkCount ||
            row.chunks.some((chunk) => chunk.embeddingStatus !== 'READY')
          )
            throw new AppError('CONFLICT');
          const prior = await tx.knowledgeDocument.findMany({
            where: { documentKey: row.documentKey, status: 'ACTIVE', id: { not: id } },
            include: diseaseInclude,
          });
          for (const old of prior) {
            await tx.knowledgeDocument.update({
              where: { id: old.id },
              data: { status: 'ARCHIVED' },
            });
            await retireSource(tx, old, actorId, requestId);
            await tx.auditLog.create({
              data: {
                actorId,
                requestId,
                action: 'DEACTIVATE',
                entityType: 'knowledge_document',
                entityId: old.id,
                changes: { status: 'ARCHIVED', replacedBy: id },
              },
            });
          }
          if (typeof metadata.sourceRecordId === 'string') {
            await tx.diseaseSource.update({
              where: { id: metadata.sourceRecordId },
              data: { status: 'ACTIVE' },
            });
            await tx.auditLog.create({
              data: {
                actorId,
                requestId,
                action: 'ACTIVATE',
                entityType: 'disease_source',
                entityId: metadata.sourceRecordId,
                changes: { status: 'ACTIVE', documentId: id },
              },
            });
          }
        } else {
          if (row.status === 'ARCHIVED') throw new AppError('CONFLICT');
          await retireSource(tx, row, actorId, requestId);
        }
        const updated = await tx.knowledgeDocument.update({
          where: { id },
          data: { status },
          include: diseaseInclude,
        });
        await tx.auditLog.create({
          data: {
            actorId,
            requestId,
            action: status === 'ACTIVE' ? 'ACTIVATE' : 'DEACTIVATE',
            entityType: 'knowledge_document',
            entityId: id,
            changes: {
              previousStatus: row.status,
              status,
              documentKey: row.documentKey,
              version: row.version,
            },
          },
        });
        return updated;
      });
    },
  };
}
