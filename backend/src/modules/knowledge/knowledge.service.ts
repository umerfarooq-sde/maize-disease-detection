import { AppError } from '../../errors/app-error.js';
import type { KnowledgeRepository } from './knowledge.repository.js';
import {
  type DiseaseDetail,
  type DiseaseSummary,
  type KnowledgeClient,
  type KnowledgeSearch,
  knowledgeSourceSchema,
  type RetrievalResult,
} from './knowledge.types.js';

export interface KnowledgeService {
  listDiseases(): Promise<{ items: DiseaseSummary[] }>;
  getDisease(slug: string): Promise<DiseaseDetail>;
  search(input: KnowledgeSearch): Promise<RetrievalResult>;
}

function summary(record: DiseaseSummary): DiseaseSummary {
  return {
    slug: record.slug,
    name: record.name,
    scientificName: record.scientificName,
    description: record.description,
  };
}

export function createKnowledgeService(
  repository: KnowledgeRepository,
  client: KnowledgeClient,
): KnowledgeService {
  return {
    async listDiseases() {
      return { items: (await repository.listDiseases()).map(summary) };
    },
    async getDisease(slug) {
      const disease = await repository.findDisease(slug);
      if (!disease) throw new AppError('NOT_FOUND');
      const sections: DiseaseDetail['sections'] = [];
      for (const document of disease.knowledgeDocuments) {
        const metadata = document.metadata;
        const source = knowledgeSourceSchema.safeParse(
          metadata !== null && typeof metadata === 'object' && !Array.isArray(metadata)
            ? metadata.source
            : undefined,
        );
        // Legacy/unreviewed records without complete attributable evidence do
        // not become public advice merely because a database row exists.
        if (!source.success || document.knowledgeType === null) continue;
        sections.push({
          documentId: document.id,
          documentKey: document.documentKey,
          documentVersion: document.version,
          knowledgeType: document.knowledgeType,
          title: document.title,
          content: document.content,
          source: source.data,
        });
      }
      return { ...summary(disease), sections };
    },
    search(input) {
      return client.search(input);
    },
  };
}
