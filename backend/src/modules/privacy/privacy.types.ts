import { z } from 'zod';

export const privacyProjection = z.strictObject({
  id: z.uuid(),
  status: z.enum(['REQUESTED', 'APPROVED', 'ASSET_CLEANUP', 'COMPLETED', 'REJECTED']),
  requestedAt: z.iso.datetime(),
  completedAt: z.iso.datetime().nullable(),
  erasureAutomaticallyEnabled: z.literal(false),
});
export const privacyResponse = z.strictObject({ request: privacyProjection.nullable() });
export type PrivacyProjection = z.infer<typeof privacyProjection>;
