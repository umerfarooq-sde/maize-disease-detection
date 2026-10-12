import type { Prisma, PrismaClient } from '../../generated/prisma/client.js';
import type { DiseaseSummary } from './knowledge.types.js';

export type KnowledgeDatabase = Pick<PrismaClient, 'disease'>;
const summarySelect = {
  slug: true,
  name: true,
  scientificName: true,
  description: true,
} as const satisfies Prisma.DiseaseSelect;

const detailSelect = {
  ...summarySelect,
  knowledgeDocuments: {
    where: { status: 'ACTIVE', topic: 'DISEASE', language: 'en', knowledgeType: { not: null } },
    orderBy: [{ knowledgeType: 'asc' }, { documentKey: 'asc' }, { version: 'desc' }],
    select: {
      id: true,
      documentKey: true,
      version: true,
      title: true,
      content: true,
      knowledgeType: true,
      metadata: true,
    },
  },
} as const satisfies Prisma.DiseaseSelect;

export type DiseaseDetailRecord = Prisma.DiseaseGetPayload<{ select: typeof detailSelect }>;
export interface KnowledgeRepository {
  listDiseases(): Promise<DiseaseSummary[]>;
  findDisease(slug: string): Promise<DiseaseDetailRecord | null>;
}

export function createKnowledgeRepository(database: KnowledgeDatabase): KnowledgeRepository {
  return {
    listDiseases() {
      return database.disease.findMany({
        where: { status: 'ACTIVE' },
        select: summarySelect,
        orderBy: [{ name: 'asc' }, { slug: 'asc' }],
      });
    },
    findDisease(slug) {
      return database.disease.findFirst({
        where: { slug, status: 'ACTIVE' },
        select: detailSelect,
      });
    },
  };
}
