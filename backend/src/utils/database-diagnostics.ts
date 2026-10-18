import { Prisma } from '../generated/prisma/client.js';

// Dependency messages can contain credentials or SQL. Classify locally only.
export function databaseDiagnostics(error: unknown) {
  if (error instanceof Error) {
    const driverStages: Record<string, string> = {
      'Query read timeout': 'QUERY_READ_TIMEOUT',
      'timeout exceeded when trying to connect': 'POOL_ACQUISITION_TIMEOUT',
      'Connection terminated unexpectedly': 'CONNECTION_TERMINATED',
      'Connection terminated due to connection timeout': 'CONNECTION_SETUP_TIMEOUT',
    };
    const stage = Object.hasOwn(driverStages, error.message)
      ? driverStages[error.message]
      : undefined;
    if (stage) return { dependencyCode: 'PG_DRIVER', databaseFailureKind: stage };
    if (error instanceof Prisma.PrismaClientUnknownRequestError) {
      // Some adapter failures are wrapped. Inspect locally, export only the same
      // bounded category; no exception message, SQL or parameter is serialized.
      const wrapped = Object.entries(driverStages).find(([text]) => error.message.includes(text));
      if (wrapped) return { dependencyCode: 'PRISMA_DRIVER', databaseFailureKind: wrapped[1] };
    }
  }
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
