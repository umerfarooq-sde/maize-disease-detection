import { Prisma, type PrismaClient } from '../../generated/prisma/client.js';
import { AppError } from '../../errors/app-error.js';
import { productInformation, productRevision, type ProductWrite } from './catalogue.types.js';
import { hashContent } from '../admin/management.types.js';
const include = {
  _count: { select: { rules: true } },
  knowledgeDocuments: {
    where: { topic: 'FERTILIZER' as const, documentKey: { startsWith: 'product-information.' } },
    orderBy: { version: 'desc' as const },
    take: 1,
  },
} as const;
export type ProductRecord = Prisma.FertilizerGetPayload<{ include: typeof include }>;
export function createProductRepository(database: PrismaClient) {
  async function locked<T>(action: (tx: Prisma.TransactionClient) => Promise<T>) {
    try {
      return await database.$transaction(
        async (tx) => {
          // Share the calculator product/rule lock so an edit cannot race a new
          // immutable rule snapshot. Referenced product content is frozen.
          await tx.$executeRaw`SELECT pg_advisory_xact_lock(17017)`;
          return action(tx);
        },
        { maxWait: 10000, timeout: 15000 },
      );
    } catch (error) {
      if (error instanceof Prisma.PrismaClientKnownRequestError && error.code === 'P2002')
        throw new AppError('CONFLICT');
      throw error;
    }
  }
  return {
    async list(cursor?: string) {
      return database.fertilizer.findMany({
        orderBy: { id: 'asc' },
        ...(cursor ? { where: { id: { gt: cursor } } } : {}),
        take: 101,
        include,
      });
    },
    write(id: string | null, input: ProductWrite, actorId: string, requestId: string) {
      return locked(async (tx) => {
        const previous = id ? await tx.fertilizer.findUnique({ where: { id }, include }) : null;
        if (id && !previous) throw new AppError('NOT_FOUND');
        const version = previous?.knowledgeDocuments[0]?.version ?? 0;
        if (
          previous &&
          (productRevision(previous, version) !== input.expectedRevision ||
            previous._count.rules > 0 ||
            previous.slug !== input.product.slug)
        )
          throw new AppError('CONFLICT');
        const row = previous
          ? await tx.fertilizer.update({
              where: { id: previous.id },
              data: { ...input.product, status: input.status },
            })
          : await tx.fertilizer.create({ data: { ...input.product, status: input.status } });
        const documentKey = `product-information.${row.slug}`;
        await tx.knowledgeDocument.updateMany({
          where: { documentKey, status: 'DRAFT' },
          data: { status: 'ARCHIVED' },
        });
        const content = JSON.stringify({ product: input.product, information: input.information });
        // Immutable sourced metadata, deliberately not an indexed RAG document.
        await tx.knowledgeDocument.create({
          data: {
            documentKey,
            version: version + 1,
            title: row.name,
            content,
            contentHash: hashContent(content),
            sourceReference: input.information.source.url,
            topic: 'FERTILIZER',
            status: 'DRAFT',
            fertilizerId: row.id,
            createdById: actorId,
            metadata: {
              purpose: 'PRODUCT_INFORMATION_ONLY',
              information: input.information,
              nutrientBasis: 'N_P2O5_K2O_PERCENT_MASS',
              reviewedAt: new Date().toISOString(),
            },
          },
        });
        await tx.auditLog.create({
          data: {
            actorId,
            requestId,
            action: previous ? 'UPDATE' : 'CREATE',
            entityType: 'fertilizer',
            entityId: row.id,
            changes: {
              version: version + 1,
              status: row.status,
              fields: { name: row.name, sourceReference: input.information.source.url },
            },
          },
        });
        return tx.fertilizer.findUniqueOrThrow({ where: { id: row.id }, include });
      });
    },
    status(
      id: string,
      revision: string,
      status: 'ACTIVE' | 'INACTIVE',
      actorId: string,
      requestId: string,
    ) {
      return locked(async (tx) => {
        const row = await tx.fertilizer.findUnique({ where: { id }, include });
        if (!row) throw new AppError('NOT_FOUND');
        if (productRevision(row, row.knowledgeDocuments[0]?.version ?? 0) !== revision)
          throw new AppError('CONFLICT');
        if (status === 'ACTIVE') {
          const metadata = row.knowledgeDocuments[0]?.metadata;
          const parsed = productInformation.safeParse(
            metadata &&
              typeof metadata === 'object' &&
              !Array.isArray(metadata) &&
              metadata.purpose === 'PRODUCT_INFORMATION_ONLY'
              ? metadata.information
              : null,
          );
          if (!parsed.success || parsed.data.source.url !== row.sourceReference)
            throw new AppError('VALIDATION_ERROR');
        }
        const updated = await tx.fertilizer.update({ where: { id }, data: { status }, include });
        await tx.auditLog.create({
          data: {
            actorId,
            requestId,
            action: status === 'ACTIVE' ? 'ACTIVATE' : 'DEACTIVATE',
            entityType: 'fertilizer',
            entityId: id,
            changes: { fromStatus: row.status, toStatus: status },
          },
        });
        return updated;
      });
    },
  };
}
export type ProductRepository = ReturnType<typeof createProductRepository>;
