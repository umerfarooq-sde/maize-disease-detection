# Phase 25: deployment and release engineering

Updated 2026-10-19 (Asia/Karachi). Baseline `5cdc775ca7f2b4b232b4141b17c7699efe593676`.
Phase 25 closeout; Phase 26/public release have not started. Final full CI39169239488
at e4c42f5 passes all four jobs. The final Windows database action uses the same
mounted-secret readiness CLI exercised by the image, not the legacy env-only probe;
its15 offline plans and real model/preflight checks are verified separately.

## Current verdict

**PARTIALLY COMPLETE: connected deployment acceptance remains unverified.** Normal E2E run
`20261018T164512Z-b78fe039` finished18 PASS/3 FAIL/0 selected skips (database,
Knowledge, generation); schema/cloud fixture cleanup and source counts passed.
Focused recovery `20261018T172334Z-f507f073` passed4 functional checks but exposed
a Python-writer fixture teardown race. It is not clean lifecycle evidence despite
its historical `passed:true` flag. The guard is fixed; fresh full
`20261018T173013Z-6deb0e3f` finished19 PASS/2 FAIL/0 selected skips. Management
records PG_DRIVER/CONNECTION_SETUP_TIMEOUT; Farmer registration/login pass but
Knowledge returns AppException(network), with no proven retrospective subtype.
Its final guard confirms server/writer stopped, telemetry pending0/dropped0,
owned schema/cloud assets removed and source counts unchanged. Do not substitute
old21/21 or combine independent runs. No further full run is used to seek a random pass.

The user confirmed no Linux Docker host/self-hosted runner exists. This Windows
host has no Docker Engine or installed WSL distribution. Standalone Compose
validation, native PostgreSQL/production-mode model serving, encrypted isolated
restore drills and loopback Caddy TLS are separate executed evidence. Hosted CI
now builds all four images, verifies real Redis quotas across two Node OS processes
and validates operational tools. The complete private model/provider stack,
full selected-model/provider monitoring and hosted rollout remain unverified. A real cleanup-worker
cycle with Redis, SQL and all three existing CLIs now passes in hosted CI, using
empty disposable asset tables and synthetic provider configuration (no provider
operation or real asset deletion is claimed by that scheduler test).

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
| Backend full | Hosted CI39150304971:371 pass/0 fail/0 skip, including real multiprocess Redis; SQL14/0/0, actual scheduler1/0/0 and environment isolation3/0/0 separately |
| TypeScript/build | Pass, `node-types-final-second.log`, `node-build-final.log` |
| OpenAPI | 61 operations validated against runtime schemas, `openapi-final-second.log` |
| Formatting | Clean Git-index sources pass; full working-tree check fails only preserved unrelated `backend/src/environment-check.ts` |
| AI | 381 pass/0 fail/4 default SQL skips; one upstream Starlette/httpx warning; Ruff/format/mypy52 pass |
| Flutter | 399 pass/0 fail/14 default live skips; analyzer pass |
| Shared package | 78 pass in each consumer environment;12 synthetic parity cases pass; no source dataset access |
| Operations | 26 pass/0 fail/2 native SQL opt-in skips; the two SQL tests also pass separately against dedicated-role disposable DBs, including real empty-bootstrap snapshot verification |
| Infrastructure CI | All four images build; Prometheus config/16 rules, Alertmanager/Alloy and five Compose variants validate; unconfigured AI startup rejects correctly; real monitoring8 checks pass |
| Shared Redis CI | Real two-OS-process atomic limits are included in CI371/0/0; actual scheduler/three CLIs also pass separately |
| Caddy | Native validation and real loopback TLS/redirect/spoof/private-path test pass against controlled upstream fixture; no hosted application claim |
| Native PostgreSQL | PG18.4/vector0.8.7,15 migrations, schema-owner grants, Node/AI/backup/privacy role audits over verified TLS; no owner/privileged/CREATE |
| Real privacy | Node request/idempotency/ownership/approval-denial pass; two disposable SQL erasure/recovery and scan-expiration/journal tests pass |
| Real model | Native production lifespan loads model once; Node prediction/schema and Node/AI event persistence pass; no Gemini generation in this probe |
| Development DB | Additive15 applied, validation/generation/status/drift pass; old table counts unchanged and privacy table empty; managed roles unchanged |
| Android | Final unsigned AAB41.3MB9.9s/APK51.5MB3.9s exported with explicit dirty-source verification provenance; ARM64 debug30.4s pass after debug-only manifest repair |
| Current E2E | 19 pass/2 fail/0 selected skips; clean owned-resource shutdown/removal and source counts preserved |

Hosted CI `39148918996` passed all four jobs at `03b9b03`. The subsequent scheduler
fixture initially violated runtime namespace/API-key validation; the fixture was
corrected, not the validator. CI `39150304971` at `af11cac` passes Node371/0/0,
SQL14/0/0, real cleanup1/0/0 and environment-isolation3/0/0; Python381/0/4,
shared78/0/0 in each environment, operators21/0/2 plus separate real SQL/role
verification; all four images/tools and mobile399/0/14 plus unsigned build/provenance pass.
CI39169239488 at e4c42f5 independently passes all four jobs with operators26/0/2,
real empty-bootstrap SQL, monitoring8 checks, and15 PowerShell command plans.
The normal mobile job now also runs the existing hosted-Pub OSV audit (47/0 locally).
Protected image publication requires the latest completed successful ci.yml push
run for the exact approved revision before registry login/build. Missing, running,
failed or mismatched evidence rejects publication; human environment review is
still required. Publication/deployment workflows are not executed by these checks.
Ordinary CI was invoked by authorized pushes; publication, deployment and protected
connected-infrastructure workflows have not been invoked.

Security refresh: npm production audit0 findings; Pub OSV47 hosted packages0
affected. pip-audit reports60 distributions,57 audited/0 findings and3 explicit
skips (editable shared package, two CPU wheels). Normalized CPU advisory review
still returns PYSEC-2025-194 and PYSEC-2026-139 for Torch2.10.0, exit1; these are
the unchanged restricted-use risks documented in the Phase24 security report.
Do not call the whole dependency estate vulnerability-free or patched.

Read-only configured-path comparison:14/14 query successes across pg/Prisma cold,
warm, concurrent and idle reconnect. Raw client TLS is encrypted/certificate-
authorized; Prisma uses the same verify-full policy. Warm SELECT timings232-775ms,
cold2.36-2.43s, reconnect1.67-2.90s, not an SLA/load test. The first probe incorrectly
required the server backend SSL flag, which is false on this configured path even
though the client TLS session is verified. Its failure is a probe-contract error,
not14 failed SQL operations or proof of insecure client transport.

The strengthened E2E teardown captures its owned recorder, waits separately for
its thread and server, and retains the owned schema/fails cleanup if either remains
active. It records pending/dropped observations. Service best-effort close remains
three seconds; no farmer request or global DB deadline was extended. The original
Node writer ownership fixes from Phase24.7 remain intact.

Hosted component startup found a genuine Compose runtime defect after static
validation had passed: YAML flow-sequence commas split the unquoted tmpfs options
into a second mount named `mode=1777`. Docker rejected that non-absolute mount.
Both64MiB/768MiB entries are now quoted; all five rendered configurations assert
absolute tmpfs paths and intact size/mode options. Failure logs39167987749 and
39168302404 are preserved; subsequent component verification is reported below.

Component run39168678601 passed real Node/DB/Redis readiness and Prometheus Node/
inbox scrapes/counters, then failed file ingestion. Retained Alloy errors prove
`mkdir /var/lib/alloy/remotecfg: permission denied`. The collector now runs as
473:473 with supplementary Node1000/AI10001 read groups, no added capabilities,
and read-only log mounts. This matches the state-directory ownership in the
[pinned upstream image](https://raw.githubusercontent.com/grafana/alloy/v1.20.1/Dockerfile).
No world-readable private logs or Docker socket are introduced.

Release-path regression also reproduced external environment edits contaminating
rollback; retained per-release environment files now select rollback configuration
before preflight, and same-release overwrites are rejected. Secret values remain
in external purpose files; retained configuration pins their paths, not a copy of
revoked credentials. Hosted rollback execution remains a separate acceptance gate.
The pre-migration snapshot now permits missing application metadata only when
the public schema has zero tables, preserving fail-closed partial-schema handling.
The disposable least-privilege SQL test exercises that bootstrap state under
md_backup before the first migration. Local operator tests26 pass/2 opt-in SQL skips.

**Real connected monitoring component: PASS**, CI39169239488 at e4c42f5,
job117798645475. Eight named checks include Node/DB/authenticated Redis readiness,
real Prometheus Node/inbox scrapes and HTTP counter, Node file -> Alloy -> Loki,
provisioned Grafana dashboard, Alertmanager -> authenticated private alert journal,
and owned-project cleanup. Private endpoint/Grafana guest denials and actual
collector UID473 assertions also pass. No domain fixtures, model, provider keys,
external notifications or source environments are used. No host ports are
published. Python job117798645684 separately verifies the empty pre-migration
snapshot with the real backup identity. This is not a hosted full application.

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

### Windows operator entry point

`scripts/operations.ps1` delegates to the same Python/Compose implementations;
it has no reset, volume deletion, ad-hoc asset deletion or automatic destructive
retry. It detects absent CLI/daemon explicitly, preserves configured stop grace
periods, sends monitoring probe source through stdin and accepts private file
paths instead of secret values. Production uses the protected release procedure,
not this local-reference wrapper. `scripts/test-operations-entrypoint.ps1` verifies
PowerShell syntax and15 offline action plans; actual Model/hash and missing-Docker
behavior and actual offline Preflight pass here. Other live container actions remain host-dependent.

```powershell
./scripts/operations.ps1 -Action Preflight
./scripts/operations.ps1 -Action Config
./scripts/operations.ps1 -Action Build
./scripts/operations.ps1 -Action Start
./scripts/operations.ps1 -Action Database
./scripts/operations.ps1 -Action Migrate
./scripts/operations.ps1 -Action Model
./scripts/operations.ps1 -Action Monitoring
./scripts/operations.ps1 -Action Cleanup
./scripts/operations.ps1 -Action Status
./scripts/operations.ps1 -Action Stop
```

`-Action Prepare` refuses an existing private directory, as the underlying tool
does. `-ShowPlan` emits an offline command plan without reading secret files or
starting services. Backup/restore use `-Action Backup` or `-Action Restore` with
`-SecretsFile`, `-BackupKeyFile`, and `-BackupFile` for Restore; optional
`-BackupDirectory`/`-ArtifactsDirectory` select external locations. A Restore is
the guarded new-database drill, not source cutover. `-Action E2E` runs the normal
native configured `check-e2e.py` owned-schema suite; it is explicitly not a remote
hosted UI test. Linux uses the equivalent Python/Compose commands above.

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
- The disposable Redis runner reports host memory-overcommit disabled. No global
  sysctl was changed. Review host `vm.overcommit_memory`, persistence/fork capacity
  and total container budgets on the authorized production machine; this warning
  is not a demonstrated successful persistence guarantee under memory pressure.
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
future commercial replacement/licensing remain. Absence of a deployment host is
an execution gate, not permission to call syntax checks a deployment.

## Acceptance boundaries and exact next actions

| Requirement | Current engineering/evidence | Remaining acceptance |
|---|---|---|
| Docker images | All four real builds pass hosted Linux CI | Connected approved-model/provider stack on an authorized host |
| SQL security | Six identities/grants implemented; four runtime identity audits and real SQL/privacy tests pass | Provider-authorized production identities, private topology and verification |
| Reliability | Bounded production DNS/connection setup, safe categories; read-only14/14 comparison passes | Current full normal run still19/21; establish stable required flows on selected host without hiding failures |
| Model | Approved hashes/parity/native production inference pass | Full private container readiness/inference with external approved artifacts |
| Monitoring | Real producers, provisioned pipeline,16 rules, safe receiver; validators pass | Component CI result below; full host observer/model/backup pipeline and operator notification acceptance |
| Cleanup | Actual shared Redis lease, SQL and three CLIs pass hosted CI | Scheduled real-provider recovery acceptance on host; no real asset deletion manufactured |
| Recovery | Two actual encrypted isolated restore drills pass, including migration15 | Off-host replication/key escrow, hosted restart/restore/rollback and agreed RPO/RTO |
| Release | Protected digest/SBOM/provenance publication and retained-config rollout/rollback tools | Authorized registry publication, runner/environments, real rollout/rollback execution |
| Android | Debug and unsigned verification APK/AAB pass | External keystore/signer, owned HTTPS API, signed build and physical device acceptance |
| Privacy | Owner request/review/fencing/recovery/expiry code and real SQL tests pass | Approved scope/retention/provider-processing policy before enabling destructive execution |
| Domain | Reviewed Knowledge and real generation execute; catalogue/media/rule review workflows exist | Licensed reference photos, approved fertilizer/yield data and richer mathematical model, confidence/field claims |

No known additional business feature is introduced here. Exact model-dependent
nutrient/schedule/forecast engines remain non-executable pending an approved
mathematical specification; source-intake contracts are not those engines. No
production credentials, content, field accuracy or licence approval is fabricated.

Mandatory operator inputs: (1) authorized Linux host and separate staging/private
DB topology; (2) owned DNS/HTTPS and protected runner/environments; (3) approved
signing identity and physical device; (4) policy/content/model-claim decisions
before public release. Existing developer provider credentials are already
configured and are not requested again. Use the procedures above, then retain
one complete hosted acceptance run and recovery/alert evidence. No deployment
or privileged workflow has been invoked automatically.

**Phase26 NOT READY. Public release NOT READY: external gates plus failed current
integration acceptance.** Historical causes cannot be established from retained
evidence. They are not proof of a provider outage, and this assessment does not
promote historical uncertainty into an automatic infinite blocker.
