import { randomUUID } from 'node:crypto';
import { AppError } from '../../errors/app-error.js';
import type { ImageStorage, ValidatedImage } from '../scans/scan.types.js';
import {
  referenceProvenance,
  storedReferenceProvenance,
  referenceRevision,
  type ReferenceMetadata,
  type referenceEdit,
  type referenceStatus,
} from './media.types.js';
import type { z } from 'zod';
import type { ReferenceRecord, ReferenceRepository } from './media.repository.js';

export function referenceProjection(row: ReferenceRecord, admin: boolean) {
  const provenance = referenceProvenance.safeParse(
    row.provenance && typeof row.provenance === 'object' && !Array.isArray(row.provenance)
      ? {
          source: row.provenance.source,
          license: row.provenance.license,
          contributor: row.provenance.contributor,
          attribution: row.provenance.attribution,
          rightsConfirmed: row.provenance.rightsConfirmed,
          contentKind: row.provenance.contentKind,
        }
      : null,
  );
  return {
    id: row.id,
    diseaseSlug: row.disease.slug,
    altText: row.altText,
    sortOrder: row.sortOrder,
    status: row.status,
    revision: referenceRevision(row),
    provenance: provenance.success ? provenance.data : null,
    imagePath:
      row.imageUrl && row.uploadState === 'READY'
        ? `${admin ? 'admin/' : ''}disease-images/${row.id}/image`
        : null,
    ...(admin ? { uploadState: row.uploadState, cleanupPending: row.cleanupPending } : {}),
    updatedAt: row.updatedAt.toISOString(),
  };
}
export function createReferenceService(
  repository: ReferenceRepository,
  storage: ImageStorage,
  allowSynthetic = false,
) {
  return {
    async list(slug: string, admin = false) {
      return {
        items: (await repository.list(slug, admin))
          .filter((row) => admin || referenceProjection(row, false).provenance !== null)
          .map((row) => referenceProjection(row, admin)),
      };
    },
    async upload(
      input: ReferenceMetadata,
      image: ValidatedImage,
      actor: string,
      requestId: string,
    ) {
      if (!storage.enabled) throw new AppError('UPLOAD_UNAVAILABLE');
      const id = randomUUID(),
        publicId = `maizedoctor/references/${randomUUID()}`;
      await repository.reserve(id, publicId, input, actor, requestId);
      try {
        const stored = await storage.upload(image, publicId);
        if (stored.publicId !== publicId) throw new AppError('UPLOAD_FAILED');
        await repository.finish(id, stored.url);
      } catch (error) {
        // The reserved identity is durable before Cloudinary. Acknowledgement
        // loss requires reread; never delete an uncertain completed upload.
        const row = await repository.read(id);
        if (!row || row.uploadState !== 'READY' || !row.imageUrl) throw error;
      }
      const row = await repository.read(id);
      if (!row) throw new AppError('NOT_FOUND');
      return referenceProjection(row, true);
    },
    async edit(id: string, input: z.infer<typeof referenceEdit>, actor: string, requestId: string) {
      const { expectedRevision, ...data } = input;
      return referenceProjection(
        await repository.mutate(id, expectedRevision, actor, requestId, () => ({
          ...data,
          status: 'DRAFT',
        })),
        true,
      );
    },
    async status(
      id: string,
      input: z.infer<typeof referenceStatus>,
      actor: string,
      requestId: string,
    ) {
      const row = await repository.mutate(
        id,
        input.expectedRevision,
        actor,
        requestId,
        (current) => {
          if (input.status === 'ACTIVE') {
            const provenance = storedReferenceProvenance(current.provenance);
            // Re-review strips any previous stamp; publication always attests a
            // fresh revision. Test fixtures cannot enter the real public corpus.
            if (
              !provenance.success ||
              !provenance.data.rightsConfirmed ||
              current.disease.status !== 'ACTIVE' ||
              (provenance.data.contentKind === 'SYNTHETIC_TEST' && !allowSynthetic)
            )
              throw new AppError('VALIDATION_ERROR');
            return {
              status: 'ACTIVE',
              provenance: {
                ...provenance.data,
                reviewedAt: new Date().toISOString(),
                reviewNote: input.reviewNote,
              },
            };
          }
          return {
            status: 'INACTIVE',
            ...(input.status === 'DELETED' ? { cleanupPending: true, uploadState: 'RETIRED' } : {}),
          };
        },
      );
      return referenceProjection(row, true);
    },
    async imageLocation(id: string, admin = false) {
      const row = await repository.read(id);
      if (
        !row ||
        !row.imageUrl ||
        row.uploadState !== 'READY' ||
        row.cleanupPending ||
        (!admin && (row.status !== 'ACTIVE' || row.disease.status !== 'ACTIVE'))
      )
        throw new AppError('NOT_FOUND');
      return {
        publicId: row.cloudinaryPublicId,
        url: row.imageUrl,
        purpose: 'references' as const,
      };
    },
    async cleanup() {
      let removed = 0,
        failed = 0;
      for (const row of await repository.cleanupCandidates()) {
        try {
          await storage.destroy(row.cloudinaryPublicId);
          await repository.cleared(row.id);
          removed++;
        } catch {
          failed++;
        }
      }
      return { removed, failed };
    },
  };
}
export type ReferenceService = ReturnType<typeof createReferenceService>;
