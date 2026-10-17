import { Prisma } from '../generated/prisma/client.js';

// Dependency messages can contain credentials or SQL. Classify locally only.
export function databaseDiagnostics(error: unknown) {
  if (!(error instanceof Prisma.PrismaClientKnownRequestError) || !/^P\d{4}$/.test(error.code))
    return {};
  let databaseFailureKind = 'DATABASE_REQUEST_FAILURE';
  if (error.code === 'P2028') {
    const message = error.message.toLowerCase();
    databaseFailureKind = message.includes('unable to start a transaction in the given time')
      ? 'TRANSACTION_ACQUISITION_TIMEOUT'
      : message.includes('expired transaction')
        ? 'TRANSACTION_DEADLINE'
        : 'TRANSACTION_FAILURE';
  }
  return { dependencyCode: error.code, databaseFailureKind };
}
