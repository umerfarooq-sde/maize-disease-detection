import { productInformation, productRevision, type ProductWrite } from './catalogue.types.js';
import type { ProductRepository, ProductRecord } from './catalogue.repository.js';
import { fertilizerProductSnapshot } from './fertilizer.repository.js';
import { AppError } from '../../errors/app-error.js';
export function productProjection(row: ProductRecord) {
  const document = row.knowledgeDocuments[0],
    meta = document?.metadata;
  const parsed = productInformation.safeParse(
    meta &&
      typeof meta === 'object' &&
      !Array.isArray(meta) &&
      meta.purpose === 'PRODUCT_INFORMATION_ONLY'
      ? meta.information
      : null,
  );
  const product = fertilizerProductSnapshot(row);
  return {
    id: row.id,
    title: row.name,
    version: document?.version ?? 0,
    status: row.status,
    revision: productRevision(row, document?.version ?? 0),
    rulesCount: row._count.rules,
    contentEditable: row._count.rules === 0,
    validForActivation: parsed.success && parsed.data.source.url === row.sourceReference,
    draftInput: { product, information: parsed.success ? parsed.data : null },
    createdAt: row.createdAt.toISOString(),
    updatedAt: row.updatedAt.toISOString(),
  };
}
export function createProductService(repository: ProductRepository) {
  return {
    async list(cursor?: string) {
      const rows = await repository.list(cursor);
      return {
        items: rows.slice(0, 100).map(productProjection),
        limit: 100,
        nextCursor: rows.length > 100 ? rows[99]!.id : null,
      };
    },
    async write(id: string | null, input: ProductWrite, actor: string, requestId: string) {
      if (id && !input.expectedRevision) throw new AppError('VALIDATION_ERROR');
      if (!id && input.expectedRevision) throw new AppError('VALIDATION_ERROR');
      return productProjection(await repository.write(id, input, actor, requestId));
    },
    async status(
      id: string,
      revision: string,
      status: 'ACTIVE' | 'INACTIVE',
      actor: string,
      requestId: string,
    ) {
      return productProjection(await repository.status(id, revision, status, actor, requestId));
    },
  };
}
export type ProductService = ReturnType<typeof createProductService>;
