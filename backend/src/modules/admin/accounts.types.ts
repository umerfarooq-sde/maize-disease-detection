import { createHash } from 'node:crypto';
import { z } from 'zod';
import type { UserStatus } from '../../generated/prisma/client.js';

export const accountStatuses = ['ACTIVE', 'SUSPENDED', 'DEACTIVATED'] as const;
export const auditActions = [
  'CREATE',
  'UPDATE',
  'ACTIVATE',
  'DEACTIVATE',
  'DELETE',
  'MODEL_PROMOTION',
] as const;
export const auditEntities = [
  'farmer_account',
  'disease',
  'disease_source',
  'knowledge_document',
  'fertilizer_rule',
  'calculator_config',
  'fertilizer',
  'model_version',
  'disease_image',
  'privacy_request',
  'privacy_scan_retention',
  'privacy_retention_run',
] as const;
const page = {
  limit: z.coerce.number().int().min(1).max(50).default(20),
  cursor: z.uuid().optional(),
};
export const farmerQuery = z.strictObject({
  ...page,
  status: z.enum(accountStatuses).optional(),
  email: z.string().trim().toLowerCase().pipe(z.email().max(254)).optional(),
});
export const statusPatch = z.strictObject({
  status: z.enum(accountStatuses),
  expectedRevision: z.string().regex(/^[a-f0-9]{64}$/),
});
export const auditQuery = z
  .strictObject({
    ...page,
    action: z.enum(auditActions).optional(),
    entityType: z.enum(auditEntities).optional(),
    actorId: z.uuid().optional(),
    from: z.iso.date().optional(),
    to: z.iso.date().optional(),
  })
  .refine((value) => {
    if (!value.from && !value.to) return true;
    if (!value.from || !value.to) return false;
    const days = (Date.parse(value.to) - Date.parse(value.from)) / 86400000;
    return days >= 0 && days < 366;
  });
export type FarmerQuery = z.infer<typeof farmerQuery>;
export type AuditQuery = z.infer<typeof auditQuery>;
export type StatusPatch = z.infer<typeof statusPatch>;
export interface FarmerRow {
  id: string;
  email: string;
  status: UserStatus;
  createdAt: Date;
  updatedAt: Date;
  farmerProfile: { displayName: string } | null;
}
export const accountRevision = (row: FarmerRow) =>
  createHash('sha256')
    .update(JSON.stringify([row.id, row.status, row.updatedAt.toISOString()]))
    .digest('hex');
export function farmerResponse(row: FarmerRow) {
  return {
    id: row.id,
    email: row.email,
    status: row.status,
    displayName: row.farmerProfile?.displayName ?? null,
    createdAt: row.createdAt.toISOString(),
    revision: accountRevision(row),
  };
}
// Never forward the polymorphic audit JSON wholesale, even for Admin.
export function safeAuditMetadata(value: unknown) {
  const result: Record<string, string | number | string[]> = {};
  if (!value || typeof value !== 'object' || Array.isArray(value)) return result;
  const data = value as Record<string, unknown>;
  for (const key of ['fromStatus', 'toStatus', 'status', 'expectedStatus']) {
    const text = data[key];
    if (
      typeof text === 'string' &&
      ['ACTIVE', 'SUSPENDED', 'DEACTIVATED', 'DRAFT', 'ARCHIVED', 'INACTIVE'].includes(text)
    )
      result[key] = text;
  }
  for (const key of ['revokedSessions', 'version', 'documentVersion']) {
    const number = data[key];
    if (
      typeof number === 'number' &&
      Number.isSafeInteger(number) &&
      number >= 0 &&
      number <= 2147483647
    )
      result[key] = number;
  }
  if (data.fields && typeof data.fields === 'object' && !Array.isArray(data.fields)) {
    result.fieldsChanged = Object.keys(data.fields).filter((key) =>
      [
        'name',
        'description',
        'scientificName',
        'status',
        'catalogueMetadata',
        'altText',
        'sortOrder',
        'provenance',
      ].includes(key),
    );
  }
  return result;
}
