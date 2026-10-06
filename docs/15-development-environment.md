# Development environment

Phase 1 configures independent toolchains and infrastructure probes. Phase 2 adds
[Prisma schema/migrations and database checks](16-database-operations.md). No
disease API, preprocessing, model training or RAG exists. Later completed phases add
the [auth backend](18-authentication.md) and [Flutter farmer foundation](19-flutter-foundation.md).
Phase 8 adds the [actual FastAPI foundation](21-ai-service-foundation.md), preserving
the independent image/CPU dependency smoke tests.

## Toolchains and locks

| Environment | Baseline | Reproducibility |
|---|---|---|
| Backend | Node.js 24.12.0, npm 11.6.2, strict TypeScript 7.0.2 | `.node-version`, `package-lock.json`, `npm ci` |
| Mobile | Flutter 3.41.9, Dart 3.11.5 | `.flutter-version`, SDK constraint, `pubspec.lock` |
| AI and training | Python 3.11, uv 0.12.23, CPU torch 2.10 / torchvision 0.25 | Separate `.python-version`, `pyproject.toml`, `uv.lock`, `.venv` |
| PostgreSQL | Native 18.4; configured Neon 18.6 | Phase 2 Compose uses `pgvector/pgvector:0.8.7-pg18-bookworm` |
| Compose validation | Official standalone Compose 5.6.0 | Release binary SHA256 verified before use |

Python supports the 3.11 series for this baseline. The installed interpreter is 3.11.0;
prefer a maintained 3.11 patch release when provisioning another workstation.
The CPU build provides a verifiable starting environment without CUDA requirements;
GPU configuration will be a deliberate later decision.
Both Python components pin OpenCV 4.13.0.92, using the standard Windows wheel and
the headless wheel on Linux. Training pins scikit-learn 1.8.0 and SciPy 1.17.1.
After interrupted downloads, existing cached wheels were verified against the
registry hashes in the lockfiles and installed into the isolated environments;
no global packages are inherited by either environment.

Locks include transitive versions and integrity hashes. Regenerate them intentionally
when upgrading dependencies; do not use an untracked global environment as the project environment.
Training and inference dependencies match, but the shared preprocessing implementation
and its package location remain future work.

## Windows setup

Commands below run from the repository root. A process-only execution-policy override
is used for scripts on systems that disable direct `.ps1` execution.

### Backend

```powershell
Set-Location backend
npm.cmd ci
npm.cmd run db:generate
npm.cmd run check
Set-Location ..
```

`check` now verifies formatting, lint, strict compilation, build, foundation tests
and the compiled dependency probe. Phase 3 adds `npm.cmd run dev` and
`npm.cmd start` (after build), listening on loopback port 3000 by default after
database readiness succeeds. See [backend foundation](17-backend-foundation.md)
for environment settings, health responses and shutdown. Application queries
belong in repositories using the shared Prisma client; `pg` also serves the
preserved SQL infrastructure probe. See the database operations guide.

### Python and ML

Install bootstrap tooling locally if `uv` is not already installed:

```powershell
python -m venv .cache/tools
./.cache/tools/Scripts/python.exe -m pip install -r scripts/requirements-tools.txt --cache-dir .cache/pip
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/setup-python.ps1
```

The setup script selects a Python 3.11 executable, disables automatic interpreter
downloads, and synchronizes each committed lock into its own virtual environment.
Use `-Python C:/path/to/python.exe` if the default interpreter is different.
The PyTorch packages use the explicit official CPU wheel index; ordinary dependencies
use PyPI. Downloads require network access. The shared uv cache is ignored by Git.

Run each environment independently:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/check-development.ps1 -Component AI
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/check-development.ps1 -Component Training
```

The AI checks now run Ruff formatting/lint, strict mypy and actual FastAPI foundation
tests as well as dependency probes. Start the configured local service with:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/start-ai.ps1
```

It listens on loopback port 8000 by default and exposes `GET /health`; no model,
database or Gemini access is needed. See [AI startup/settings](21-ai-service-foundation.md).
ML checks use synthetic arrays and tensors, exercise autograd and compiled torchvision
operators, and verify scikit-learn metrics. No weights or dataset are downloaded.

### Flutter

Use the configured SDK version, then:

```powershell
Set-Location mobile
flutter pub get
flutter analyze
flutter test
flutter doctor -v
Set-Location ..
```

Android platform files were generated using the minimal empty app template. The
Phase 5 widget/unit tests verify navigation, responsive/accessibility states,
ViewModels and the API client. `.env.example` is public build configuration documentation;
it is not bundled as an asset or automatically loaded. Configure the API with
`--dart-define=API_BASE_URL=...`; omit it to explore the offline shell. Release URLs
must use HTTPS. See [Flutter setup and live check](19-flutter-foundation.md).

Analyzer and widget tests work without a complete Android SDK. On this workstation,
the missing Android command-line tools were downloaded from Google's official source,
SHA256 verified, and installed in the existing SDK without overwriting its packages.
The final `flutter doctor` check identifies some outstanding SDK license agreements.
Run `flutter doctor --android-licenses` interactively to review those agreements, then
rerun `flutter doctor -v`. APK builds are not yet verified. On a new workstation,
install **Android SDK Command-line Tools (latest)** through Android Studio's SDK Manager first.

### Local environment files

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/initialize-dev-env.ps1
```

This creates ignored `infrastructure/.env`, `backend/.env`, and `ai-service/.env`
when missing, generating a random local password without printing it. Existing
files are preserved. Template credentials remain blank. Phase 4 fills only missing
local JWT keys using initialize-auth-env.ps1; supplied keys are preserved and never
printed. AI operational settings are loaded in Phase 8; database/Gemini/model settings
remain unused by FastAPI. See [authentication](18-authentication.md)
for required keys, cookies, endpoints and controlled admin provisioning.

Newly generated database URLs point to `127.0.0.1:5433/maizedoctor`. Existing custom
URLs are preserved; Phase 2 used the user's configured Neon development database.
The native and Docker
alternatives below use the same local settings, but have separate persistent storage.
Start only one on port 5433. The default avoids the existing system server on port 5432.
The generated role is a local cluster administrator, not a production application role;
least-privilege accounts belong in the future database/security implementation.

### PostgreSQL: native Windows alternative

If PostgreSQL 18 is installed:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/postgres-local.ps1 -Action Start
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/check-development.ps1 -Component Database
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/postgres-local.ps1 -Action Stop
```

Set `-PostgresBin` or `MAIZEDOCTOR_PG_BIN` for a different installation directory.
The script initializes only `infrastructure/data/postgres`, uses password authentication,
and binds the development server to localhost. Stop preserves data. It does not alter
the existing Windows PostgreSQL service. Starting the server may need sandbox approval.
This startup script creates no schema or migrations. The native installation needs
pgvector before Phase 2 migration execution. The Node probe performs a temporary-table SQL
round trip and rolls back all writes.

### PostgreSQL: Docker alternative

With a running Docker Engine/Desktop:

```powershell
docker compose --env-file infrastructure/.env -f infrastructure/compose.yaml config --quiet
docker compose --env-file infrastructure/.env -f infrastructure/compose.yaml up -d
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/check-development.ps1 -Component Database
docker compose --env-file infrastructure/.env -f infrastructure/compose.yaml down
```

Only PostgreSQL is containerized. Its healthcheck uses `pg_isready`; the named volume
mount at `/var/lib/postgresql` matches the PostgreSQL 18 image layout. `down` retains
the named volume. Phase 2 uses a pgvector maintainer image with the extension included.
Run the explicit migration commands in the database operations guide after startup.

Docker Desktop/Engine is absent on this workstation. For configuration validation
alone, the official standalone Compose binary can be stored as
`.cache/tools/docker-compose.exe`. Obtain release 5.6.0 from the official release page
and compare `Get-FileHash -Algorithm SHA256` against its published `.sha256` file before use.
The development checker uses that binary when Docker is unavailable:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/check-development.ps1 -Component Docker
```

This validates interpolation and the Compose schema without starting containers.
Container runtime verification remains unavailable until Docker Engine is installed.

## Combined checks

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/check-repository.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/check-development.ps1 -Component All
git diff --check
```

The development checker reports each environment separately and fails overall if any
component fails. Configure a running pgvector database and apply migrations before
selecting `All`; its `Prisma` check requires the Phase 2 schema.
It does not automatically install tools, accept licenses, or start servers.

## Reference documentation

- [TypeScript Node module configuration](https://www.typescriptlang.org/docs/handbook/esm-node.html)
- [Flutter minimal app creation](https://docs.flutter.dev/reference/create-new-app)
- [FastAPI virtual environments](https://fastapi.tiangolo.com/virtual-environments/)
- [PyTorch versioned CPU installations](https://docs.pytorch.org/get-started/previous-versions/)
- [PostgreSQL official container image](https://hub.docker.com/_/postgres)
- [Docker Compose official release](https://github.com/docker/compose/releases/tag/v5.6.0)
- [Android SDK command-line tools](https://developer.android.com/studio#command-line-tools-only)
