import { Prisma, type PrismaClient } from '../../generated/prisma/client.js';
import { YIELD_CONFIG_KEY } from './yield.types.js';

export type YieldConfigurationRecord = Prisma.CalculatorConfigGetPayload<Record<string, never>>;
export type YieldDatabase = Pick<PrismaClient, 'calculatorConfig' | 'auditLog' | '$transaction'>;
export interface YieldRepository {
  list(activeOnly: boolean): Promise<YieldConfigurationRecord[]>;
  find(id: string): Promise<YieldConfigurationRecord | null>;
  createDraft(
    input: { version: number; parameters: Prisma.InputJsonObject; sourceReference: string },
    actorId: string,
    requestId: string,
  ): Promise<YieldConfigurationRecord | null>;
  changeStatus(
    id: string,
    status: 'ACTIVE' | 'INACTIVE',
    actorId: string,
    requestId: string,
    admit: (record: YieldConfigurationRecord) => boolean,
  ): Promise<YieldConfigurationRecord | 'INVALID' | null>;
}
export function createYieldRepository(database: YieldDatabase): YieldRepository {
  const identity = { kind: 'YIELD' as const, configKey: YIELD_CONFIG_KEY };
  return {
    list(activeOnly) {
      return database.calculatorConfig.findMany({
        where: { ...identity, ...(activeOnly ? { status: 'ACTIVE' } : {}) },
        orderBy: { version: 'desc' },
        take: 100,
      });
    },
    find(id) {
      return database.calculatorConfig.findFirst({ where: { id, ...identity } });
    },
    async createDraft(input, actorId, requestId) {
      try {
        return await database.$transaction(
          async (transaction) => {
            await transaction.$executeRaw`SELECT pg_advisory_xact_lock(18018)`;
            if (
              await transaction.calculatorConfig.findUnique({
                where: { kind_configKey_version: { ...identity, version: input.version } },
              })
            )
              return null;
            const configuration = await transaction.calculatorConfig.create({
              data: {
                ...identity,
                ...input,
                unit: 'kg/ha',
                status: 'DRAFT',
                createdById: actorId,
              },
            });
            await transaction.auditLog.create({
              data: {
                actorId,
                requestId,
                action: 'CREATE',
                entityType: 'yield_configuration',
                entityId: configuration.id,
                changes: {
                  version: configuration.version,
                  status: 'DRAFT',
                  configKey: YIELD_CONFIG_KEY,
                },
              },
            });
            return configuration;
          },
          { maxWait: 10000, timeout: 15000 },
        );
      } catch (error) {
        if (error instanceof Prisma.PrismaClientKnownRequestError && error.code === 'P2002')
          return null;
        throw error;
      }
    },
    changeStatus(id, status, actorId, requestId, admit) {
      return database.$transaction(
        async (transaction) => {
          await transaction.$executeRaw`SELECT pg_advisory_xact_lock(18018)`;
          const previous = await transaction.calculatorConfig.findFirst({
            where: { id, ...identity },
          });
          if (!previous) return null;
          const retired =
            status === 'ACTIVE'
              ? await transaction.calculatorConfig.findMany({
                  where: { ...identity, status: 'ACTIVE', id: { not: id } },
                  select: { id: true, version: true },
                })
              : [];
          if (status === 'ACTIVE') {
            if (!admit(previous)) return 'INVALID';
            await transaction.calculatorConfig.updateMany({
              where: { ...identity, status: 'ACTIVE', id: { not: id } },
              data: { status: 'INACTIVE' },
            });
          }
          const updated = await transaction.calculatorConfig.update({
            where: { id },
            data: { status },
          });
          await transaction.auditLog.create({
            data: {
              actorId,
              requestId,
              action: status === 'ACTIVE' ? 'ACTIVATE' : 'DEACTIVATE',
              entityType: 'yield_configuration',
              entityId: id,
              changes: {
                previousStatus: previous.status,
                status,
                version: previous.version,
                configKey: YIELD_CONFIG_KEY,
                retiredVersions: retired,
              },
            },
          });
          return updated;
        },
        { maxWait: 10000, timeout: 15000 },
      );
    },
  };
}
