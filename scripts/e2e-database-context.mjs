// Test-only schema setup. No application query/result is replaced or mocked.
import assert from 'node:assert/strict';
import pg from '../backend/node_modules/pg/lib/index.js';

const owned = process.env.PHASE23_SCHEMA;
process.env.PHASE23_DB_CONTEXT_LOADED = '1';
assert.match(owned ?? '', /^phase23_[a-f0-9]{32}$/);
const OriginalPool = pg.Pool;
pg.Pool = class IsolatedVerificationPool extends OriginalPool {
  constructor(configuration) {
    const url = configuration?.connectionString ? new URL(configuration.connectionString) : null;
    const target = url?.searchParams.get('schema');
    if (target !== owned) {
      super(configuration);
      return;
    }
    assert.ok(
      !url.hostname.includes('-pooler'),
      'Schema-isolated SQL requires the configured direct connection.',
    );
    const previous = configuration.onConnect;
    super({
      ...configuration,
      onConnect: async (client) => {
        await previous?.(client);
        await client.query("SELECT set_config('search_path',$1,false)", [`${owned},public`]);
        assert.equal(
          (await client.query('SELECT current_schema() AS schema')).rows[0].schema,
          owned,
        );
      },
    });
  }
};
