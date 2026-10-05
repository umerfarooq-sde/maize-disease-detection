export function databaseConnectionUrl(connectionString = process.env['DATABASE_URL']): URL {
  if (!connectionString) throw new Error('DATABASE_URL is required.');
  const url = new URL(connectionString);
  if (
    !['postgres:', 'postgresql:'].includes(url.protocol) ||
    !url.hostname ||
    url.pathname.length < 2
  ) {
    throw new Error('DATABASE_URL must identify a PostgreSQL server and database.');
  }
  // Preserve certificate verification when pg changes its SSL alias semantics.
  if (
    ['prefer', 'require', 'verify-ca'].includes(url.searchParams.get('sslmode') ?? '') &&
    url.searchParams.get('uselibpqcompat') !== 'true'
  ) {
    url.searchParams.set('sslmode', 'verify-full');
  }
  return url;
}
