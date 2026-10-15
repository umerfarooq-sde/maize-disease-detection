import { sameJson as sameFertilizerSnapshot } from '../../utils/json-equality.js';
export { sameJson as sameFertilizerSnapshot } from '../../utils/json-equality.js';
import { Prisma, type PrismaClient } from '../../generated/prisma/client.js';
import type { FertilizerProductInput } from './fertilizer.validators.js';

const ruleInclude = { fertilizer: true } as const satisfies Prisma.FertilizerRuleInclude;
export type FertilizerRuleRecord = Prisma.FertilizerRuleGetPayload<{
  include: typeof ruleInclude;
}>;
export type FertilizerConfigRecord = Prisma.CalculatorConfigGetPayload<Record<string, never>>;
export type FertilizerDatabase = Pick<
  PrismaClient,
  'fertilizer' | 'fertilizerRule' | 'calculatorConfig' | 'auditLog' | '$transaction'
>;

export interface FertilizerSnapshot {
  rules: FertilizerRuleRecord[];
  configs: FertilizerConfigRecord[];
}

export interface FertilizerRepository {
  catalogue(configKey: string): Promise<FertilizerSnapshot>;
  calculation(ruleId: string, configKey: string): Promise<FertilizerSnapshot>;
  drafts(configKey: string): Promise<FertilizerSnapshot>;
  createDraft(
    input: FertilizerDraftWrite,
    actorId: string,
    requestId: string,
  ): Promise<FertilizerRuleRecord | null>;
  changeStatus(
    ruleId: string,
    status: 'ACTIVE' | 'INACTIVE',
    actorId: string,
    requestId: string,
    configKey: string,
    admit: (rule: FertilizerRuleRecord, config: FertilizerConfigRecord) => boolean,
  ): Promise<FertilizerRuleRecord | 'INVALID' | null>;
}

export interface FertilizerDraftWrite {
  product: FertilizerProductInput;
  rule: {
    ruleKey: string;
    version: number;
    parameters: Prisma.InputJsonObject;
    sourceReference: string;
  };
  config: {
    configKey: string;
    version: number;
    parameters: Prisma.InputJsonObject;
    sourceReference: string;
  };
}

export function fertilizerProductSnapshot(
  product: FertilizerRuleRecord['fertilizer'],
): FertilizerProductInput {
  return {
    slug: product.slug,
    name: product.name,
    description: product.description,
    nitrogenPercent: product.nitrogenPercent.toFixed(2),
    phosphorusPercent: product.phosphorusPercent.toFixed(2),
    potassiumPercent: product.potassiumPercent.toFixed(2),
    applicationMethod: product.applicationMethod,
    precautions: product.precautions,
    sourceReference: product.sourceReference,
  };
}

export function createFertilizerRepository(database: FertilizerDatabase): FertilizerRepository {
  function snapshot(ruleId: string | undefined, configKey: string) {
    return database.$transaction(
      async (transaction) => {
        const rules = await transaction.fertilizerRule.findMany({
          where: {
            status: 'ACTIVE',
            fertilizer: { status: 'ACTIVE' },
            ...(ruleId ? { id: ruleId } : {}),
          },
          include: ruleInclude,
          orderBy: [{ fertilizerId: 'asc' }, { ruleKey: 'asc' }, { version: 'desc' }],
          take: 100,
        });
        const configs = await transaction.calculatorConfig.findMany({
          where: { kind: 'FERTILIZER', configKey, status: 'ACTIVE' },
          orderBy: { version: 'desc' },
        });
        return { rules, configs };
      },
      { isolationLevel: Prisma.TransactionIsolationLevel.RepeatableRead },
    );
  }
  return {
    catalogue(configKey) {
      return snapshot(undefined, configKey);
    },
    calculation(ruleId, configKey) {
      return snapshot(ruleId, configKey);
    },
    drafts(configKey) {
      return database.$transaction(
        async (transaction) => ({
          rules: await transaction.fertilizerRule.findMany({
            include: ruleInclude,
            orderBy: { createdAt: 'desc' },
            take: 100,
          }),
          configs: await transaction.calculatorConfig.findMany({
            where: { kind: 'FERTILIZER', configKey },
            orderBy: { version: 'desc' },
            take: 100,
          }),
        }),
        { isolationLevel: Prisma.TransactionIsolationLevel.RepeatableRead },
      );
    },
    async createDraft(input, actorId, requestId) {
      try {
        return await database.$transaction(
          async (transaction) => {
            // One calculator-wide lock keeps draft reuse and publication consistent.
            // It is held only while this short metadata transaction runs.
            await transaction.$executeRaw`SELECT pg_advisory_xact_lock(17017)`;
            let product = await transaction.fertilizer.findUnique({
              where: { slug: input.product.slug },
            });
            if (
              product &&
              !sameFertilizerSnapshot(fertilizerProductSnapshot(product), input.product)
            )
              return null;
            const previousConfig = await transaction.calculatorConfig.findUnique({
              where: {
                kind_configKey_version: {
                  kind: 'FERTILIZER',
                  configKey: input.config.configKey,
                  version: input.config.version,
                },
              },
            });
            if (
              previousConfig &&
              (!sameFertilizerSnapshot(previousConfig.parameters, input.config.parameters) ||
                previousConfig.unit !== 'kg' ||
                previousConfig.sourceReference !== input.config.sourceReference)
            )
              return null;
            if (product) {
              const previousRule = await transaction.fertilizerRule.findUnique({
                where: {
                  fertilizerId_ruleKey_version: {
                    fertilizerId: product.id,
                    ruleKey: input.rule.ruleKey,
                    version: input.rule.version,
                  },
                },
              });
              if (previousRule) return null;
            }
            if (!product)
              product = await transaction.fertilizer.create({
                data: { ...input.product, status: 'DRAFT' },
              });
            if (!previousConfig)
              await transaction.calculatorConfig.create({
                data: {
                  kind: 'FERTILIZER',
                  ...input.config,
                  unit: 'kg',
                  status: 'DRAFT',
                  createdById: actorId,
                },
              });
            const rule = await transaction.fertilizerRule.create({
              data: {
                fertilizerId: product.id,
                ...input.rule,
                unit: 'kg/ha',
                status: 'DRAFT',
              },
              include: ruleInclude,
            });
            await transaction.auditLog.create({
              data: {
                actorId,
                requestId,
                action: 'CREATE',
                entityType: 'fertilizer_rule',
                entityId: rule.id,
                changes: {
                  ruleKey: rule.ruleKey,
                  version: rule.version,
                  status: 'DRAFT',
                  configVersion: input.config.version,
                },
              },
            });
            return rule;
          },
          { maxWait: 10000, timeout: 15000 },
        );
      } catch (error) {
        if (error instanceof Prisma.PrismaClientKnownRequestError && error.code === 'P2002')
          return null;
        throw error;
      }
    },
    changeStatus(ruleId, status, actorId, requestId, configKey, admit) {
      return database.$transaction(
        async (transaction) => {
          await transaction.$executeRaw`SELECT pg_advisory_xact_lock(17017)`;
          const rule = await transaction.fertilizerRule.findUnique({
            where: { id: ruleId },
            include: ruleInclude,
          });
          if (!rule) return null;
          let retiredRules: { id: string; version: number }[] = [];
          let retiredConfigs: { id: string; version: number }[] = [];
          if (status === 'ACTIVE') {
            const parameters = rule.parameters;
            const configVersion =
              parameters && typeof parameters === 'object' && !Array.isArray(parameters)
                ? parameters.configVersion
                : undefined;
            if (
              typeof configVersion !== 'number' ||
              !Number.isSafeInteger(configVersion) ||
              configVersion <= 0
            )
              return 'INVALID';
            const config = await transaction.calculatorConfig.findUnique({
              where: {
                kind_configKey_version: { kind: 'FERTILIZER', configKey, version: configVersion },
              },
            });
            if (!config || !admit(rule, config)) return 'INVALID';
            retiredRules = await transaction.fertilizerRule.findMany({
              where: {
                fertilizerId: rule.fertilizerId,
                ruleKey: rule.ruleKey,
                status: 'ACTIVE',
                id: { not: ruleId },
              },
              select: { id: true, version: true },
            });
            retiredConfigs = await transaction.calculatorConfig.findMany({
              where: { kind: 'FERTILIZER', configKey, status: 'ACTIVE', id: { not: config.id } },
              select: { id: true, version: true },
            });
            await transaction.fertilizerRule.updateMany({
              where: {
                fertilizerId: rule.fertilizerId,
                ruleKey: rule.ruleKey,
                status: 'ACTIVE',
                id: { not: ruleId },
              },
              data: { status: 'INACTIVE' },
            });
            await transaction.calculatorConfig.updateMany({
              where: {
                kind: 'FERTILIZER',
                configKey,
                status: 'ACTIVE',
                id: { not: config.id },
              },
              data: { status: 'INACTIVE' },
            });
            await transaction.calculatorConfig.update({
              where: { id: config.id },
              data: { status: 'ACTIVE' },
            });
            await transaction.fertilizer.update({
              where: { id: rule.fertilizerId },
              data: { status: 'ACTIVE' },
            });
          }
          const updated = await transaction.fertilizerRule.update({
            where: { id: ruleId },
            data: { status },
            include: ruleInclude,
          });
          await transaction.auditLog.create({
            data: {
              actorId,
              requestId,
              action: status === 'ACTIVE' ? 'ACTIVATE' : 'DEACTIVATE',
              entityType: 'fertilizer_rule',
              entityId: ruleId,
              changes: {
                previousStatus: rule.status,
                status,
                ruleKey: rule.ruleKey,
                version: rule.version,
                retiredRules,
                retiredConfigs,
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
