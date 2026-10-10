import { isDeepStrictEqual } from 'node:util';
import { Prisma, type PrismaClient } from '../../generated/prisma/client.js';
import type { ApprovedModel } from './model-registration.js';

export async function registerModelVersion(database: PrismaClient, model: ApprovedModel) {
  const verifyExisting = async () => {
    const existing = await database.modelVersion.findUniqueOrThrow({
      where: { version: model.version },
    });
    const { status: _status, ...expected } = model;
    const actual = Object.fromEntries(
      Object.keys(expected).map((key) => [key, existing[key as keyof typeof existing]]),
    );
    if (
      !['VALIDATED', 'PRODUCTION'].includes(existing.status) ||
      !isDeepStrictEqual(actual, expected)
    )
      throw new Error('Existing model version differs; registration cannot overwrite it.');
    return existing;
  };
  if (await database.modelVersion.findUnique({ where: { version: model.version } }))
    return verifyExisting();
  try {
    return await database.modelVersion.create({ data: model });
  } catch (error) {
    if (error instanceof Prisma.PrismaClientKnownRequestError && error.code === 'P2002')
      return verifyExisting();
    throw error;
  }
}
