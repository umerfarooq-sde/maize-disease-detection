import { Prisma, type PrismaClient } from '../../generated/prisma/client.js';
import { AppError } from '../../errors/app-error.js';
import type { ModelSpecification } from './model-specification.types.js';
export function createSpecificationRepository(database: PrismaClient) {
  return {
    async list() {
      return database.calculatorConfig.findMany({
        where: { configKey: { startsWith: 'model-intake.' }, status: 'DRAFT' },
        orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
        take: 100,
      });
    },
    async create(input: ModelSpecification, actorId: string, requestId: string) {
      try {
        return await database.$transaction(
          async (tx) => {
            const configKey = `model-intake.${input.modelKey}`;
            await tx.$executeRaw`SELECT pg_advisory_xact_lock(hashtextextended(${configKey},0))`;
            const latest = await tx.calculatorConfig.findFirst({
              where: { configKey, kind: input.kind },
              orderBy: { version: 'desc' },
            });
            if ((latest?.version ?? 0) !== input.expectedVersion) throw new AppError('CONFLICT');
            const row = await tx.calculatorConfig.create({
              data: {
                configKey,
                kind: input.kind,
                version: input.expectedVersion + 1,
                parameters: {
                  purpose: 'MODEL_SPECIFICATION_ONLY',
                  domainApproval: 'PENDING_DOMAIN_APPROVAL',
                  execution: 'DISABLED',
                  input,
                  reviewedAt: new Date().toISOString(),
                },
                unit: 'SPECIFICATION_ONLY',
                sourceReference: input.source.url,
                createdById: actorId,
                status: 'DRAFT',
              },
            });
            await tx.auditLog.create({
              data: {
                actorId,
                requestId,
                action: 'CREATE',
                entityType: 'calculator_config',
                entityId: row.id,
                changes: {
                  version: row.version,
                  status: 'DRAFT',
                  fields: { modelKey: input.modelKey, execution: 'DISABLED' },
                },
              },
            });
            return row;
          },
          { maxWait: 10000, timeout: 15000 },
        );
      } catch (error) {
        if (error instanceof Prisma.PrismaClientKnownRequestError && error.code === 'P2002')
          throw new AppError('CONFLICT');
        throw error;
      }
    },
  };
}
export type SpecificationRepository = ReturnType<typeof createSpecificationRepository>;
