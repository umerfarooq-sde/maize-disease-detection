import { Prisma, type PrismaClient } from '../../generated/prisma/client.js';
import { AppError } from '../../errors/app-error.js';
import { referenceRevision, type ReferenceMetadata } from './media.types.js';
import type { Logger } from 'pino';
const include = { disease: { select: { slug: true, status: true } } } as const;
export type ReferenceRecord = Prisma.DiseaseImageGetPayload<{ include: typeof include }>;
export function createReferenceRepository(database: PrismaClient, logger?: Pick<Logger, 'warn'>) {
  function failure(error: unknown) {
    if (!(error instanceof AppError))
      logger?.warn({
        event: 'reference_database_failed',
        code:
          error instanceof Prisma.PrismaClientKnownRequestError && /^P\d{4}$/.test(error.code)
            ? error.code
            : 'UNKNOWN',
      });
  }
  const read = async (id: string) => database.diseaseImage.findUnique({ where: { id }, include });
  async function transaction<T>(action: (tx: Prisma.TransactionClient) => Promise<T>) {
    try {
      return await database.$transaction(
        async (tx) => {
          await tx.$executeRaw`SELECT pg_advisory_xact_lock(hashtextextended('maizedoctor-reference-media-v1',0))`;
          return action(tx);
        },
        { maxWait: 10000, timeout: 15000 },
      );
    } catch (error) {
      if (error instanceof Prisma.PrismaClientKnownRequestError && error.code === 'P2002')
        throw new AppError('CONFLICT');
      failure(error);
      throw error;
    }
  }
  return {
    read,
    async list(slug: string, admin: boolean) {
      return database.diseaseImage.findMany({
        where: {
          disease: { slug, ...(!admin ? { status: 'ACTIVE' } : {}) },
          ...(!admin ? { status: 'ACTIVE', cleanupPending: false, uploadState: 'READY' } : {}),
        },
        include,
        orderBy: [{ sortOrder: 'asc' }, { id: 'asc' }],
        take: 100,
      });
    },
    reserve(
      id: string,
      publicId: string,
      input: ReferenceMetadata,
      actorId: string,
      requestId: string,
    ) {
      return transaction(async (tx) => {
        const disease = await tx.disease.findUnique({ where: { slug: input.diseaseSlug } });
        if (!disease) throw new AppError('NOT_FOUND');
        if (input.replacementFor) {
          const previous = await tx.diseaseImage.findUnique({
            where: { id: input.replacementFor },
          });
          if (!previous || previous.diseaseId !== disease.id || previous.cleanupPending)
            throw new AppError('CONFLICT');
        }
        const row = await tx.diseaseImage.create({
          data: {
            id,
            diseaseId: disease.id,
            cloudinaryPublicId: publicId,
            imageUrl: null,
            altText: input.altText,
            sortOrder: input.sortOrder,
            provenance: input.provenance,
            uploadState: 'UPLOADING',
            replacementFor: input.replacementFor ?? null,
          },
          include,
        });
        await tx.auditLog.create({
          data: {
            actorId,
            requestId,
            action: 'CREATE',
            entityType: 'disease_image',
            entityId: id,
            changes: { status: 'DRAFT' },
          },
        });
        return row;
      });
    },
    finish(id: string, url: string) {
      return transaction(async (tx) => {
        const changed = await tx.diseaseImage.updateMany({
          where: { id, uploadState: 'UPLOADING', cleanupPending: false },
          data: { imageUrl: url, uploadState: 'READY' },
        });
        if (changed.count !== 1) throw new AppError('CONFLICT');
      });
    },
    mutate(
      id: string,
      revision: string,
      actorId: string,
      requestId: string,
      change: (row: ReferenceRecord) => Prisma.DiseaseImageUpdateInput,
    ) {
      return transaction(async (tx) => {
        const row = await tx.diseaseImage.findUnique({ where: { id }, include });
        if (!row) throw new AppError('NOT_FOUND');
        if (
          referenceRevision(row) !== revision ||
          row.uploadState !== 'READY' ||
          row.cleanupPending
        )
          throw new AppError('CONFLICT');
        const data = change(row);
        if (data.status === 'ACTIVE' && row.replacementFor) {
          const previous = await tx.diseaseImage.findUnique({ where: { id: row.replacementFor } });
          if (
            !previous ||
            previous.diseaseId !== row.diseaseId ||
            previous.cleanupPending ||
            previous.uploadState === 'RETIRED'
          )
            throw new AppError('CONFLICT');
        }
        const updated = await tx.diseaseImage.update({ where: { id }, data, include });
        if (data.status === 'ACTIVE' && row.replacementFor) {
          await tx.diseaseImage.updateMany({
            where: { id: row.replacementFor, diseaseId: row.diseaseId, status: 'ACTIVE' },
            data: { status: 'INACTIVE', cleanupPending: true, uploadState: 'RETIRED' },
          });
        }
        await tx.auditLog.create({
          data: {
            actorId,
            requestId,
            action: 'UPDATE',
            entityType: 'disease_image',
            entityId: id,
            changes: {
              previousRevision: revision,
              revision: referenceRevision(updated),
              previousMetadata: {
                altText: row.altText,
                sortOrder: row.sortOrder,
                provenance: row.provenance,
              },
              fields: {
                status: updated.status,
                altText: updated.altText,
                sortOrder: updated.sortOrder,
                provenance: updated.provenance,
              },
            },
          },
        });
        return updated;
      });
    },
    async cleanupCandidates() {
      // Atomically retire stale attempts before authorizing deletion; finish
      // cannot revive them, including a lost provider/DB acknowledgement.
      await transaction(async (tx) => {
        await tx.diseaseImage.updateMany({
          where: { uploadState: 'UPLOADING', createdAt: { lt: new Date(Date.now() - 120000) } },
          data: { uploadState: 'RETIRED', status: 'INACTIVE', cleanupPending: true },
        });
      });
      return database.diseaseImage.findMany({
        where: { cleanupPending: true, status: 'INACTIVE', uploadState: 'RETIRED' },
        take: 20,
      });
    },
    async cleared(id: string) {
      try {
        await database.diseaseImage.updateMany({
          where: { id, cleanupPending: true, status: 'INACTIVE', uploadState: 'RETIRED' },
          data: { cleanupPending: false, imageUrl: null },
        });
      } catch (error) {
        failure(error);
        throw error;
      }
    },
  };
}
export type ReferenceRepository = ReturnType<typeof createReferenceRepository>;
