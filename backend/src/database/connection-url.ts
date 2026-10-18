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
  const keys = [...url.searchParams.keys()];
  if (new Set(keys).size !== keys.length) {
    // URLSearchParams.get uses the first value, but pg applies the last value.
    // Ambiguous SSL/schema options must not bypass startup validation.
    throw new Error('DATABASE_URL query parameters must be unique.');
  }
  if (keys.some((key) => ['host', 'hostaddr', 'port'].includes(key))) {
    throw new Error('DATABASE_URL endpoint must be specified in the URL authority.');
  }
  // Preserve certificate verification when pg changes its SSL alias semantics.
  if (['prefer', 'require', 'verify-ca'].includes(url.searchParams.get('sslmode') ?? '')) {
    url.searchParams.set('sslmode', 'verify-full');
  }
  return url;
}

export function hasVerifiedDatabaseTransport(url: URL): boolean {
  return (
    ['localhost', '127.0.0.1', '[::1]'].includes(url.hostname) ||
    (url.searchParams.get('sslmode') === 'verify-full' && !url.searchParams.has('ssl'))
  );
}
