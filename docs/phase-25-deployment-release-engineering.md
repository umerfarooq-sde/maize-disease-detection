# Phase 25: deployment and release engineering

Updated 2026-10-18. Baseline `5cdc775ca7f2b4b232b4141b17c7699efe593676`.
Phase 25 verification is in progress; Phase 26/public release have not started.

## Current verdict

**PARTIALLY COMPLETE: final verification in progress.** Normal E2E run
`20261018T164512Z-b78fe039` has database, Knowledge and generation failures;
remaining checks and fixture cleanup are running. Do not substitute old21/21
evidence or individual component passes for this current full run.

The user confirmed no Linux Docker host/self-hosted runner exists. This Windows
host has no Docker Engine or installed WSL distribution. Standalone Compose
validation, native PostgreSQL/production-mode model serving, encrypted isolated
restore drills and loopback Caddy TLS are separate executed evidence. Hosted CI
now builds all four images, verifies real Redis quotas across two Node OS processes
and validates operational tools. The complete private model/provider stack,
connected monitoring/schedulers and hosted rollout remain unverified.

Historical Phase24.7 acceptance remains unchanged: `20261017T213205Z-173ed748`
21/0/0, `20261017T215921Z-b412d414`4/0/0 and
`20261018T014159Z-55b5db42`4/0/0. These are dated results, not Phase25 results.

## Architecture and implementation

```text
Flutter -> HTTPS/Caddy -> Node replicas -> PostgreSQL/pgvector
                                  |  -> private Redis shared admission
                                  |  -> protected Cloudinary byte delivery
                                  +  -> private authenticated FastAPI
                                        -> shared preprocessing/approved model
                                        -> curated retrieval/Google/Gemini
Private operations: cleanup, encrypted backup, policy-disabled privacy worker,
Prometheus, Alertmanager, bounded inbox, Grafana, Alloy and Loki.
```

Only Caddy publishes ports. Separate internal edge/service/data/monitoring and
purpose-specific egress networks avoid exposing AI/Redis/database. No Docker
socket is mounted into applications. Caddy overwrites forwarded headers; Node
trusts only the edge CIDR. Private operations/docs paths are blocked at the edge.

| Area | Implemented files and behavior |
|---|---|
| Images | `backend/Dockerfile` runtime/migration targets; `ai-service/Dockerfile`; `infrastructure/operations/Dockerfile`; allowlisted root `.dockerignore` |
| Locks | Node24.22.0/npm lock, Python3.11.17/uv0.12.23/CPU inference lock, hash-locked operations dependencies |
| Compose | `infrastructure/runtime/compose.yaml` and local/staging/production overrides; production Node replicas2 |
| Secrets | Allowlisted mounted JSON, conflict rejection, no dotenv fallback when selected; empty contracts in `runtime/secret-templates` |
| Readiness | Real database/TLS/privilege checks, Redis state, model health plus configured registry version; once-loaded model lifespan |
| Quotas | Official Redis SDK, atomic account/IP rate counters and concurrency leases, HMAC identities/IPv6 aggregation, bounded queue/deadlines, fail-closed503/429 |
| Cleanup | Serial scheduler, distributed owner lease/heartbeat, bounded existing scan/profile/reference cleanup CLIs and durable recovery journals |
| Database | Six separate identities, verified TLS, bounded production Python DNS/all-address connect budget, safe pool/query/stage metrics |
| Observability | Rotating privacy-minimal logs, read-only Alloy to private Loki, authenticated metrics, replica discovery, Grafana operational panels, bounded host observer |
| Alerts | Dependency/model/Redis/pool/telemetry/cleanup/backup/storage/container rules and actual private inbox; no external paging channel claimed |
| Recovery | AES-256-GCM immutable backups, exported SQL snapshot, authenticated isolated restore, approved model artifacts; no raw source dataset |
| Privacy | Owner-bound review requests, operator approval/erasure/recovery/retention machinery; every default scope remains disabled |
| Release | Protected manual publication with SBOM/provenance/digests, external state/configuration bundles, host lock, backup/migration/grant/curation gates and explicit compatible rollback |

Original application layers and protected image delivery remain. Four classifier
labels, full-frame preprocessing1.0.0, null threshold and temperature1 are fixed.
Model registration is VALIDATED, never automatic production promotion. No training
or final test-set scoring is invoked.

## Executed evidence

Do not add overlapping runs together or relabel opt-in skips.

| Check | Result / `.cache/phase25/` evidence |
|---|---|
| Backend full | 366 pass/0 fail/1 Redis opt-in skip, `node-tests-final.log`; later disconnect regression passes separately |
| TypeScript/build | Pass, `node-types-final-second.log`, `node-build-final.log` |
| OpenAPI | 61 operations validated against runtime schemas, `openapi-final-second.log` |
| Formatting | Clean Git-index sources pass; full working-tree check fails only preserved unrelated `backend/src/environment-check.ts` |
| AI | 381 pass/0 fail/4 default SQL skips; one upstream Starlette/httpx warning; Ruff/format/mypy52 pass |
| Flutter | 399 pass/0 fail/14 default live skips; analyzer pass |
| Shared package | 78 pass in each consumer environment;12 synthetic parity cases pass; no source dataset access |
| Operations | 21 pass/0 fail/2 native SQL opt-in skips; the two SQL tests also pass separately against dedicated-role disposable DBs |
| Infrastructure CI | All four images build; Prometheus config/16 rules, Alertmanager/Alloy and four Compose variants validate; unconfigured AI startup rejects correctly |
| Shared Redis CI | 368/0/0 backend run includes actual two-OS-process atomic limits; later backend changes have a separate run |
| Caddy | Native validation and real loopback TLS/redirect/spoof/private-path test pass against controlled upstream fixture; no hosted application claim |
| Native PostgreSQL | PG18.4/vector0.8.7,15 migrations, schema-owner grants, Node/AI/backup/privacy role audits over verified TLS; no owner/privileged/CREATE |
| Real privacy | Node request/idempotency/ownership/approval-denial pass; two disposable SQL erasure/recovery and scan-expiration/journal tests pass |
| Real model | Native production lifespan loads model once; Node prediction/schema and Node/AI event persistence pass; no Gemini generation in this probe |
| Development DB | Additive15 applied, validation/generation/status/drift pass; old table counts unchanged and privacy table empty; managed roles unchanged |
| Android | Unsigned AAB33.2MB187.3s/APK51.5MB74.3s exported with provenance; ARM64 debug30.4s pass after debug-only manifest repair |
| Current E2E | Running with retained failures; not a full pass |

### Actual encrypted restore drills

Configured source: `20261018T111554Z-075b60ccfb6f4283bbc2ab5cd091e586.mdb`,
6,512,677 bytes, SHA256
`5313c1b4292608368aae41ac068eb3c1c6ab3d0d2d07c9326d0d14768d31d1b4`.
Backup86.594s/restore167.454s;23 tables including history,14 migrations,28 foreign
keys and approved artifacts verified. Source unchanged; new owned target removed.

Final native source: `20261018T161515Z-b385f7852114456d86931d9c75d4eb8a.mdb`,
6,410,277 bytes, SHA256
`1bb7380eea3500a369868d8f1dff012feb7b31f1cdf63317d8bba0e7ff60c942`.
Backup10.781s/restore27.203s;24 tables including history,15 migrations,30 foreign
keys/artifacts verified; receipt persisted, target removed and cluster stopped.
This disposable DB did not contain a full production knowledge/model registry;
do not claim otherwise. No source database was reset or overwritten.

### Confirmed fixes

AI idempotent telemetry needs SELECT(id), and privacy/document SELECT FOR UPDATE
needs narrow UPDATE(id). Actual SQLSTATE42501 reproduction and corrected checks
retain denial of content updates. Prisma now explicitly matches migration15's
ON UPDATE NO ACTION; the first drift failure is retained and no applied SQL was
rewritten. Android debug manifest explicitly overrides development HTTP while
release stays false. External retained Git configuration bundles prevent checkout
cleaning or rollback from mixing configurations. Real archive testing caught and
fixed parent-directory handling without admitting private/untracked files.
Replica observation cannot hide a failed replica behind a later healthy one.
CI bootstrap fixes scope a non-connecting Prisma codegen URL and fetch the actual
Flutter3.41.9 tag, asserting the approved commit. Linux test font lookup handles
SDK filename case while still failing missing/ambiguous fonts. Release output now
records dirty-source verification, and distributable builds require a clean checkout.
New deployment credentials are redacted from console as well as central logs.

Disk exhaustion interrupted an earlier backup encryption/AAB provenance export.
Only generated caches moved with contents and original paths preserved by local
junctions. Real assets, source databases and weights were untouched. Failures stay
in local evidence. Historical connectivity attribution is still unproved.

## Local production-like stack

Requires Linux Docker/Compose2.24+, sufficient disk/RAM (plan12GB free build space
and8GB RAM), approved model files and existing provider configuration. No such
host is available here; commands are implemented but connected execution is pending.

```bash
python -m pip install uv==0.12.23
cd ai-service && uv sync --locked && cd ..
uv pip install --python ai-service/.venv/bin/python --require-hashes -r infrastructure/operations/requirements.lock
ai-service/.venv/bin/python infrastructure/operations/manage.py prepare-local
ai-service/.venv/bin/python infrastructure/operations/manage.py preflight --local --environment-file infrastructure/runtime/.env.local
docker compose --env-file infrastructure/runtime/.env.local -f infrastructure/runtime/compose.yaml -f infrastructure/runtime/compose.local.yaml config --quiet
docker compose --env-file infrastructure/runtime/.env.local -f infrastructure/runtime/compose.yaml -f infrastructure/runtime/compose.local.yaml up -d --build --wait --wait-timeout 1200
docker compose --env-file infrastructure/runtime/.env.local -f infrastructure/runtime/compose.yaml -f infrastructure/runtime/compose.local.yaml ps
```

Windows uses `ai-service/.venv/Scripts/python.exe`. Local private files have already
been prepared; the command refuses to overwrite them. Do not delete an existing
secret directory to bypass that guard. Local DB uses its own new named volume.
Never run `down --volumes`, reset databases or prune provider assets.
`https://api.localhost:8443` uses a local Caddy root; export it from the owned
volume and trust it explicitly per test client, never `--insecure` or automatic
global CA installation. Ingestion uses real configured Google embeddings/quota
for the reviewed corpus only. Physical device/emulator CA/routing acceptance is
separate from a loopback TLS protocol test.

## Staging / production procedure

1. Supply Linux Docker host, private DB connectivity and owned DNS. Use separate
   staging/production DBs, Redis namespaces, credentials and assets. No provider
   account/resources are invented or provisioned here.
2. Fill the deployment environment template outside Git with absolute model,
   secret and policy paths, actual HTTPS origin and exact CORS origins. Fill empty
   [secret contracts](../infrastructure/runtime/secret-templates/README.md) privately.
   Escrow the32-byte backup key separately; verify all three pinned model files.
3. A provider-authorized administrator reviews role SQL before applying it:

```bash
/opt/maizedoctor-operations/bin/python infrastructure/operations/manage.py export-role-sql --secrets /etc/maizedoctor/private/operator.json --output /etc/maizedoctor/private/reviewed-roles.sql
/opt/maizedoctor-operations/bin/python infrastructure/operations/manage.py verify-model --artifacts /srv/maizedoctor-model
```

   SQL contains passwords: never print/commit it. The migrator owns app objects,
   with USAGE WITH GRANT OPTION on provider-owned vector; app identities cannot
   own schema/create roles/databases. Runtime rollout only grants reviewed objects
   and never rotates credentials. Managed role/production changes need authorization.
4. Configure protected GitHub environments `release-images`, `staging`, `production`
   with reviewers/branch restrictions; dedicated trusted deploy runners must never
   run PR CI. Install the hash-locked operations venv at `/opt/maizedoctor-operations`.
   Set `DEPLOY_ENV_FILE`, `RELEASE_MANIFEST`, `DEPLOY_STATE_DIRECTORY` to private
   absolute host paths. State must be outside checkout/models/secrets.
5. After CI, manually publish the approved full commit through `publish-images.yml`.
   Review its four image digests/SBOM/provenance and additive-schema compatibility,
   then transfer release.json privately. No publication/rollout has been invoked.
6. Explicitly reviewed staging rollout and connected checks:

```bash
/opt/maizedoctor-operations/bin/python infrastructure/operations/release.py --root "$PWD" --environment-file /etc/maizedoctor/staging.env --manifest /etc/maizedoctor/release.json --state /srv/maizedoctor-staging-state --deployment-environment staging --allow-migrations
/opt/maizedoctor-operations/bin/python infrastructure/operations/verify_stack.py --environment-file /etc/maizedoctor/staging.env --state /srv/maizedoctor-staging-state --environment staging
```

   Preflight -> encrypted backup -> additive migrations -> schema-owner grants ->
   VALIDATED model registration -> reviewed ingestion -> runtime startup -> private
   readiness -> verified HTTPS. Connected probes require real scrape/backup/service
   observations and private alert delivery. No fake zero or static substitute.
7. Run complete farmer/Admin E2E, failures/ownership and physical device acceptance
   separately. `scripts/check-e2e.py` uses owned schema isolation/local configured
   providers, not a remote hosted UI. Production uses its template/override and
   `--deployment-environment production` with separate state and explicit release
   approval. Neither staging nor production hosting is claimed.

## Rollback and disaster recovery

```bash
/opt/maizedoctor-operations/bin/python infrastructure/operations/release.py --root "$PWD" --environment-file /etc/maizedoctor/staging.env --manifest /etc/maizedoctor/release.json --state /srv/maizedoctor-staging-state --deployment-environment staging --rollback
/opt/maizedoctor-operations/bin/python infrastructure/operations/manage.py backup --secrets /etc/maizedoctor/private/backup.json --output /srv/maizedoctor-backups --key /etc/maizedoctor/private/backup-key --artifacts /srv/maizedoctor-model
/opt/maizedoctor-operations/bin/python infrastructure/operations/manage.py restore-drill --secrets /etc/maizedoctor/private/operator.json --backup /srv/maizedoctor-backups/REVIEWED-ARCHIVE.mdb --key /etc/maizedoctor/private/backup-key
```

Rollback requires a retained compatible image/config bundle; no old migration or
corpus job runs, and DDL is never reversed automatically. Reconcile interrupted
live services/state before manually clearing a host lock. Restore administrator
must be permitted to create/drop a NEW phase25_restore_UUID database; the backup
reader cannot. Authentication precedes DB creation; counts/migrations/FKs/model
hashes are checked and only the owned target removed. Actual recovery/cutover
requires human review. Replicate encrypted archives off-host and escrow keys;
no bucket/account or off-host replication is claimed. Backup24h is a schedule,
not approved legal retention or an agreed RPO/RTO.

## Operations / incident checklist

- Review/install the host observer systemd service/timer on the trusted Docker
  host. Set private token-file path/namespace/alerts URL in observer.env. No socket
  is mounted into apps. Grafana/Prometheus access requires private tunnel/VPN.
- Lifecycle observations expire120s; unavailable/missing data remains unknown and
  alerts. Per-replica collection uses [Prometheus DNS discovery](https://prometheus.io/docs/prometheus/latest/configuration/configuration/#dns_sd_config).
- Logs/queues are bounded. Inspect storage alarms before builds; never remove user
  assets/unapproved backups. Loki automatic deletion remains off pending policy;
  supply capacity. Cleanup uses shared leases/journal fencing, not duplicate cron.
- Best-effort telemetry loss is observable and cannot corrupt farmer responses;
  a warning is not a persisted event. External paging is still a separate operator
  channel/acceptance gate; no external message was sent.
- Inspect safe DNS/acquisition/query/transaction/shutdown categories and SQLSTATE.
  Provider/network records are separate evidence. Do not disable TLS, grant
  ownership, extend all timeouts or add unlimited retries to hide failures.

## Privacy and Android release

Profile -> Your account data uses MVVM/repository/owner-authenticated GET/POST
`/api/v1/profile/data-deletion`; strict empty JSON, X-Auth-Request, no-store.
Submission timeout reconciles one GET; duplicates are idempotent. A request is for
review, not immediate erasure. An external approved policy pins version/hash,
approval reference and six scopes. Operator approval freezes/revokes the Farmer,
waits for quiescence, fences/detaches atomically and cleans only detached assets.
Uncertain acknowledgements preserve durable state/identity; audit records remain
with nullable deleted actors. Every default policy scope is disabled; no real user
has been erased and retention approval is not fabricated.

Android ID `com.maizedoctor.maizedoctor`, staging `.staging`. Release has no debug
signing fallback and cleartext=false. Supply four external signing variables and
the approved public signer SHA256; no keystore/password reaches Dart/Git:

```powershell
./scripts/build-android-release.ps1 -Environment staging -ApiBaseUrl https://YOUR-OWNED-API/api/v1 -Format appbundle -BuildNumber 25
```

Signature verification and version/commit/hash manifests precede distribution.
Unsigned verification explicitly requires its switch and remains non-distributable.
No real signer, Play upload, hosted API/device acceptance or macOS/iOS build is
claimed. Production cleartext checks remain independent of debug HTTP overrides.

## Remaining original-product gates

Licensed disease images remain absent; rights/review publication gates and empty
gallery behavior remain. Real fertilizer rates, nutrient/schedule models, yield
coefficients/forecasts and approvals are not invented. Model confidence/field
generalization remains limited; non-commercial academic dataset restrictions and
future commercial replacement/licensing remain. Current unfinished code/failed
tests/remote CI results will be recorded at final closeout. Absence of Docker is
an execution gate, not permission to call syntax checks a deployment.
