import { createHash } from 'node:crypto';
import { z } from 'zod';
import type { FarmerProfile } from '../../generated/prisma/client.js';

const readable = (maximum: number) =>
  z
    .string()
    .trim()
    .min(1)
    .refine(
      (value) =>
        Array.from(value).length <= maximum &&
        !Array.from(value).some((character) => {
          const code = character.codePointAt(0) ?? 0;
          return code < 32 || code === 127;
        }),
    );
export const profilePatch = z
  .strictObject({
    expectedRevision: z
      .string()
      .regex(/^[a-f0-9]{64}$/)
      .nullable(),
    displayName: readable(120).optional(),
    region: readable(120).nullable().optional(),
    countryCode: z
      .string()
      .trim()
      .toUpperCase()
      .regex(/^[A-Z]{2}$/)
      .nullable()
      .optional(),
    fieldAreaHectares: z
      .string()
      .regex(/^(?:0|[1-9][0-9]{0,7})(?:\.[0-9]{1,4})?$/)
      .refine((value) => Number(value) > 0)
      .nullable()
      .optional(),
  })
  .refine((input) => Object.keys(input).length > 1)
  .refine((input) => input.expectedRevision !== null || input.displayName !== undefined);
export type ProfilePatch = z.infer<typeof profilePatch>;
export function profileResponse(row: FarmerProfile | null) {
  if (!row) return { profile: null };
  const profile = {
    displayName: row.displayName,
    region: row.region,
    countryCode: row.countryCode,
    fieldAreaHectares: row.fieldAreaHectares?.toString() ?? null,
    avatarUrl: row.avatarUrl,
    updatedAt: row.updatedAt.toISOString(),
  };
  return {
    profile: {
      ...profile,
      revision: createHash('sha256').update(JSON.stringify(profile)).digest('hex'),
    },
  };
}
export type ProfileResponse = ReturnType<typeof profileResponse>;
