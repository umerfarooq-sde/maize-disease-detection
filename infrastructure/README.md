# Infrastructure

Phase 2 uses the pgvector maintainer's `0.8.7-pg18-bookworm` PostgreSQL image,
which includes the extension required by the database migration, with a healthcheck,
persistent named volume, and port bound to `127.0.0.1:5433`. No application images
or hosting resources are configured.

`.env.example` defines local PostgreSQL settings. `scripts/initialize-dev-env.ps1`
can generate ignored local credentials. A native Windows PostgreSQL fallback stores
its cluster in ignored `data/postgres/`; Compose uses its own Docker named volume.
Choose one runtime for port 5433. The existing system database on port 5432 is separate.

```powershell
docker compose --env-file infrastructure/.env -f infrastructure/compose.yaml config --quiet
docker compose --env-file infrastructure/.env -f infrastructure/compose.yaml up -d
docker compose --env-file infrastructure/.env -f infrastructure/compose.yaml down
```

Run these from the repository root when Docker Engine/Desktop is available.
`down` preserves the named data volume. The standalone Compose CLI can validate
configuration without an engine, but cannot start containers by itself.
The configured Neon development database has been migrated. The native Windows
cluster still needs pgvector installed before these migrations can run there.
Container startup is unverified because Docker Engine is absent on this workstation.
See [database operations](../docs/16-database-operations.md).
See [development setup](../docs/15-development-environment.md) and [deployment](../docs/13-deployment.md).
