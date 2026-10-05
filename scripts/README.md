# Scripts

Run `./scripts/check-repository.ps1` from any working directory using PowerShell and Git.
It resolves the repository relative to the script, verifies foundation and development configuration files/directories,
checks that templates contain no credentials, and checks Git ignore behavior without
creating probe files. It exits nonzero on failure and does not modify the repository.

Phase 1 adds these scripts, invoked from the repository root:

| Script | Purpose |
|---|---|
| `initialize-dev-env.ps1` | Generate ignored local database credentials and component `.env` files without overwriting existing files |
| `postgres-local.ps1 -Action Start/Check/Stop` | Operate an isolated native Windows development cluster using PostgreSQL 18 tools |
| `setup-python.ps1 -Component ai-service/ml-training/All` | Install locked dependencies into separate component virtual environments |
| `check-development.ps1 -Component Backend/AI/Training/Flutter/Database/Prisma/Docker/All` | Run checks independently; aggregate failures when checking all |

Example:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/check-development.ps1 -Component Backend
```

`Docker` validates Compose configuration; it does not verify a running engine.
Database checks require a running development database. Flutter checks require
write access to the installed SDK cache. See [development setup](../docs/15-development-environment.md).
`Prisma` verifies an already migrated pgvector database; it does not apply migrations.
See [database operations](../docs/16-database-operations.md) for migration/replay/seed commands.

If Windows blocks script execution, use
`powershell -NoProfile -ExecutionPolicy Bypass -File ./scripts/check-repository.ps1`
from the repository root. This override applies only to that process.
