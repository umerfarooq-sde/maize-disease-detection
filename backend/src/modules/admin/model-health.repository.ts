import type { PrismaClient } from '../../generated/prisma/client.js';
import { registryModelSchema, type RegistryModel } from './model-health.types.js';

export interface ModelHealthRepository {
  registry(): Promise<{ models: RegistryModel[]; productionVersions: string[] }>;
}
export function createModelHealthRepository(
  database: Pick<PrismaClient, '$transaction'>,
): ModelHealthRepository {
  return {
    registry: () =>
      database.$transaction(
        async (tx) => {
          const [rows, production] = await Promise.all([
            tx.modelVersion.findMany({
              orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
              take: 50,
              select: {
                version: true,
                architecture: true,
                datasetVersion: true,
                preprocessingVersion: true,
                status: true,
                createdAt: true,
              },
            }),
            tx.modelVersion.findMany({
              where: { status: 'PRODUCTION' },
              orderBy: { version: 'asc' },
              take: 2,
              select: { version: true },
            }),
          ]);
          return {
            models: rows.map(({ createdAt, ...row }) =>
              registryModelSchema.parse({ ...row, registeredAt: createdAt.toISOString() }),
            ),
            productionVersions: production.map((row) => row.version),
          };
        },
        { isolationLevel: 'RepeatableRead' },
      ),
  };
}
