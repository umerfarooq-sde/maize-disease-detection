import { createHash } from 'node:crypto';
import { z } from 'zod';
import { managementText, sourceSchema, managedSlug } from '../admin/management.types.js';
export const referenceProvenance = z.strictObject({
  source: sourceSchema,
  license: managementText(1000),
  contributor: managementText(255),
  attribution: managementText(1000),
  rightsConfirmed: z.boolean(),
  contentKind: z.enum(['REFERENCE', 'SYNTHETIC_TEST']),
});
export const referenceMetadata = z.strictObject({
  diseaseSlug: managedSlug,
  altText: managementText(255),
  sortOrder: z.number().int().min(0).max(10000),
  provenance: referenceProvenance,
  replacementFor: z.uuid().optional(),
});
export const referenceEdit = referenceMetadata
  .omit({ diseaseSlug: true, replacementFor: true })
  .extend({
    expectedRevision: z.string().regex(/^[a-f0-9]{64}$/),
  });
export const referenceStatus = z.strictObject({
  status: z.enum(['ACTIVE', 'INACTIVE', 'DELETED']),
  expectedRevision: z.string().regex(/^[a-f0-9]{64}$/),
  reviewNote: managementText(2000).min(20),
});
export const referenceRevision = (row: {
  id: string;
  updatedAt: Date;
  altText?: string;
  sortOrder?: number;
  status?: string;
  provenance?: unknown;
  uploadState?: string;
  cleanupPending?: boolean;
}) =>
  createHash('sha256')
    .update(
      JSON.stringify([
        row.id,
        row.updatedAt.toISOString(),
        row.altText,
        row.sortOrder,
        row.status,
        row.provenance,
        row.uploadState,
        row.cleanupPending,
      ]),
    )
    .digest('hex');
export type ReferenceMetadata = z.infer<typeof referenceMetadata>;
export function storedReferenceProvenance(raw: unknown) {
  if (!raw || typeof raw !== 'object' || Array.isArray(raw))
    return referenceProvenance.safeParse(null);
  const value = raw as Record<string, unknown>;
  return referenceProvenance.safeParse(
    Object.fromEntries(
      ['source', 'license', 'contributor', 'attribution', 'rightsConfirmed', 'contentKind'].map(
        (key) => [key, value[key]],
      ),
    ),
  );
}
