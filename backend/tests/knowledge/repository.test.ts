import assert from 'node:assert/strict';
import { test } from 'node:test';
import {
  createKnowledgeRepository,
  type KnowledgeDatabase,
} from '../../src/modules/knowledge/knowledge.repository.js';
import { disease } from './helpers.js';

test('Prisma disease reads bind active status and explicit projections, including reviewed section filters', async () => {
  const calls: { operation: string; args: unknown }[] = [];
  const database = {
    disease: {
      async findMany(args: unknown) {
        calls.push({ operation: 'list', args });
        return [disease];
      },
      async findFirst(args: unknown) {
        calls.push({ operation: 'detail', args });
        return { ...disease, knowledgeDocuments: [] };
      },
    },
  } as unknown as KnowledgeDatabase;
  const repository = createKnowledgeRepository(database);
  assert.deepEqual(await repository.listDiseases(), [disease]);
  assert.deepEqual(await repository.findDisease('common-rust'), {
    ...disease,
    knowledgeDocuments: [],
  });
  const summarySelect = { slug: true, name: true, scientificName: true, description: true };
  assert.deepEqual(calls[0], {
    operation: 'list',
    args: {
      where: { status: 'ACTIVE' },
      select: summarySelect,
      orderBy: [{ name: 'asc' }, { slug: 'asc' }],
    },
  });
  assert.deepEqual(calls[1], {
    operation: 'detail',
    args: {
      where: { slug: 'common-rust', status: 'ACTIVE' },
      select: {
        ...summarySelect,
        knowledgeDocuments: {
          where: {
            status: 'ACTIVE',
            topic: 'DISEASE',
            language: 'en',
            knowledgeType: { not: null },
          },
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
      },
    },
  });
});
