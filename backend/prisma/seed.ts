import { createDatabaseClient } from '../src/database/client.js';
import { seedData } from './seed-data.js';

const prisma = createDatabaseClient();
try {
  await prisma.$transaction(async (tx) => {
    for (const disease of seedData.diseases) {
      await tx.disease.upsert({ where: { slug: disease.slug }, create: disease, update: {} });
    }
    for (const fertilizer of seedData.fertilizers) {
      await tx.fertilizer.upsert({ where: { slug: fertilizer.slug }, create: fertilizer, update: {} });
    }
    for (const configuration of seedData.calculatorConfigs) {
      await tx.calculatorConfig.upsert({
        where: { kind_configKey_version: {
          kind: configuration.kind, configKey: configuration.configKey, version: configuration.version,
        } },
        create: configuration, update: {},
      });
    }
    for (const document of seedData.knowledgeDocuments) {
      await tx.knowledgeDocument.upsert({
        where: { documentKey_version: { documentKey: document.documentKey, version: document.version } },
        create: document, update: {},
      });
    }
  }, { maxWait: 10000, timeout: 60000 });
  console.log('Seed complete. Existing records were preserved; empty fixture groups insert nothing.');
} catch (error) {
  console.error('Seed failed. Verify database migrations and reviewed fixture data.');
  const details = error as { name?: string; code?: string };
  console.error(`Diagnostic: ${details.name ?? 'Error'} (${details.code ?? 'no code'}).`);
  process.exitCode = 1;
} finally {
  await prisma.$disconnect();
}
