import type { Prisma } from '../src/generated/prisma/client.js';

// Populate only with reviewed, sourced project records. No default credentials or facts.
export const seedData: {
  diseases: Prisma.DiseaseCreateInput[];
  fertilizers: Prisma.FertilizerCreateInput[];
  calculatorConfigs: Prisma.CalculatorConfigCreateInput[];
  knowledgeDocuments: Prisma.KnowledgeDocumentCreateInput[];
} = {
  diseases: [],
  fertilizers: [],
  calculatorConfigs: [],
  knowledgeDocuments: [],
};
