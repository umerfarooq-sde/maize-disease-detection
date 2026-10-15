import type { AccountsRepository } from './accounts.repository.js';
import {
  type AuditQuery,
  type FarmerQuery,
  type StatusPatch,
  auditEntities,
  farmerResponse,
  safeAuditMetadata,
} from './accounts.types.js';

export function createAccountsService(repository: AccountsRepository) {
  return {
    async farmers(query: FarmerQuery) {
      const page = await repository.farmers(query);
      return { ...page, items: page.items.map(farmerResponse) };
    },
    async status(id: string, input: StatusPatch, actorId: string, requestId: string) {
      return { farmer: farmerResponse(await repository.status(id, input, actorId, requestId)) };
    },
    async audits(query: AuditQuery) {
      const page = await repository.audits(query);
      return {
        ...page,
        items: page.items.map((row) => ({
          id: row.id,
          action: row.action,
          entityType: auditEntities.find((type) => type === row.entityType) ?? 'OTHER',
          entityId: row.entityId,
          createdAt: row.createdAt.toISOString(),
          actor: row.actor,
          metadata: safeAuditMetadata(row.changes),
        })),
      };
    },
  };
}
export type AccountsService = ReturnType<typeof createAccountsService>;
