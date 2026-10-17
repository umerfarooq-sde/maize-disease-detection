# Phase 24.6 — original requirements recheck

> Current Phase 24.7 evidence: see [integration stabilization](phase-24-7-integration-stability.md).
> The following Phase 24.6 results are preserved; they are not a claim of
> uninterrupted Phase 24.7 acceptance.

Updated 2026-10-17 (Asia/Karachi). Authority and original requirement text remain
in the [historical Phase 24.5 matrix](phase-24-5-requirements-matrix.md), grounded
in the original master user prompt, later phase instructions and approvals.
This matrix supersedes current-state conclusions without rewriting that evidence.

COMPLETE means the stated engineering boundary has implementation and tests; it
does not confer agronomic, licensing, calibration, commercial or production approval.
Provider-dependent verification is reported by run in the
[verification ledger](phase-24-6-verification.md). A synthetic arithmetic/media
fixture is not approved recommendation/reference content. Missing model-dependent
numeric outputs are explicitly absent, even though their review framework exists.
No Phase 25 or 26 begins.

| ID | Original intended behavior | Current disposition | Evidence / exact remaining gate |
|---|---|---|---|
| F01 | M: anonymous maize scans, no invented account history | COMPLETE AND VERIFIED | Existing implementation and relevant component/security/live regression contracts retained. See the verification ledger for actual provider-run failures and acceptance limits. |
| F02 | M: Farmer registration, validation and clean duplicate handling | COMPLETE AND VERIFIED | Existing implementation and relevant component/security/live regression contracts retained. See the verification ledger for actual provider-run failures and acceptance limits. |
| F03 | M: login/logout/access JWT/refresh/revocation | COMPLETE AND VERIFIED | Existing implementation and relevant component/security/live regression contracts retained. See the verification ledger for actual provider-run failures and acceptance limits. |
| F04 | M: customizable private farmer profile | COMPLETE AND VERIFIED | Existing implementation and relevant component/security/live regression contracts retained. See the verification ledger for actual provider-run failures and acceptance limits. |
| F05 | M: Farmer profile images | COMPLETE AND VERIFIED | Existing implementation and relevant component/security/live regression contracts retained. See the verification ledger for actual provider-run failures and acceptance limits. |
| F06 | M: select/capture, preview, submit and recover selection | BLOCKED BY ACTUAL EXTERNAL INPUT | Picker architecture and tests pass; native camera/permissions still require an attached device and acceptance. |
| F07 | M: truthful processing/loading/error/retry | COMPLETE AND VERIFIED | Existing implementation and relevant component/security/live regression contracts retained. See the verification ledger for actual provider-run failures and acceptance limits. |
| F08 | M: authoritative file MIME/type/size/decode checks | COMPLETE AND VERIFIED | Existing implementation and relevant component/security/live regression contracts retained. See the verification ledger for actual provider-run failures and acceptance limits. |
| F09 | M: disease label/confidence/status/image/time | COMPLETE AND VERIFIED | Existing implementation and relevant component/security/live regression contracts retained. See the verification ledger for actual provider-run failures and acceptance limits. |
| F10 | M/X: grounded symptoms/management/precautions/info and Ask AI action | COMPLETE AND VERIFIED | Existing source-grounded bounded implementation retained; deterministic security/failure tests pass. Actual provider-dependent successes and failures are separately reported, not treated as uniformly successful. |
| F11 | M: private authenticated scan history | COMPLETE AND VERIFIED | Existing implementation and relevant component/security/live regression contracts retained. See the verification ledger for actual provider-run failures and acceptance limits. |
| F12 | M: visual personal scan statistics | COMPLETE AND VERIFIED | Existing implementation and relevant component/security/live regression contracts retained. See the verification ledger for actual provider-run failures and acceptance limits. |
| F13 | M: browse/search/category/detail disease library | COMPLETE AND VERIFIED | Existing implementation and relevant component/security/live regression contracts retained. See the verification ledger for actual provider-run failures and acceptance limits. |
| F14 | M: scientific name/overview/symptoms/causes/conditions/management/prevention/references | COMPLETE AND VERIFIED | Existing implementation and relevant component/security/live regression contracts retained. See the verification ledger for actual provider-run failures and acceptance limits. |
| F15 | M: affected growth stages/severity management/display | PARTIALLY IMPLEMENTED | Sourced optional applicability/revision/audit/Admin/Farmer workflow exists; no unsupported stage/severity facts are seeded. Final full-run Farmer reviewed-detail UI assertion fails; focused live pass does not close acceptance. Engineering exists; approved real content also remains pending. |
| F16 | M/L: disease reference images, source/license and Admin publication/gallery | PARTIALLY IMPLEMENTED | Full reference upload/review/protected delivery/gallery/replacement/retirement/cleanup works with generated fixtures. No approved real media. Final full-run Farmer reviewed-detail UI assertion fails; focused live pass does not close acceptance. Engineering exists; approved real content also remains pending. |
| F17 | M/X: scoped conversational agricultural assistant | COMPLETE AND VERIFIED | Existing source-grounded bounded implementation retained; deterministic security/failure tests pass. Actual provider-dependent successes and failures are separately reported, not treated as uniformly successful. |
| F18 | M: retrieve evidence and show source-backed answers, abstain when missing | COMPLETE AND VERIFIED | Existing source-grounded bounded implementation retained; deterministic security/failure tests pass. Actual provider-dependent successes and failures are separately reported, not treated as uniformly successful. |
| F19 | M: explain classifier result without changing it | COMPLETE AND VERIFIED | Existing source-grounded bounded implementation retained; deterministic security/failure tests pass. Actual provider-dependent successes and failures are separately reported, not treated as uniformly successful. |
| F20 | X: bounded local conversation rather than unlimited/persisted chat | COMPLETE AND VERIFIED | Existing implementation and relevant component/security/live regression contracts retained. See the verification ledger for actual provider-run failures and acceptance limits. |
| F21 | M/L: deterministic fertilizer quantities from reviewed rules | COMPLETE WITH APPROVED EXTERNAL CONTENT PENDING | AREA_RATE_V1 framework and versioned source review pass; real product-mass recommendation rules remain PENDING_RULES. |
| F22 | M/L: N/P/K requirement, recommendation, timing and application guidance | BLOCKED BY ACTUAL EXTERNAL INPUT | Dimensioned nutrient-model intake and standalone product catalogue are implemented. N/P/K demand, product selection and schedules require approved model/data and subsequent exact model-dependent engine/UI implementation; these outputs are absent. |
| F23 | M: exact area/mass units and version/source/rounding | COMPLETE AND VERIFIED | Existing implementation and relevant component/security/live regression contracts retained. See the verification ledger for actual provider-run failures and acceptance limits. |
| F24 | M/L: conditional deterministic expected yield | COMPLETE WITH APPROVED EXTERNAL CONTENT PENDING | Existing conditional area × reviewed yield-rate projection passes; real approved scenario remains PENDING_CONFIGURATION. |
| F25 | M/L: minimum/expected/potential forecast outputs | BLOCKED BY ACTUAL EXTERNAL INPUT | Versioned minimum/expected/potential model-specification intake is implemented and disabled. An approved mathematical model/coefficients/worked cases are required before its model-dependent numerical API/UI can be implemented. |
| F26 | O: Gemini may explain deterministic calculations | OPTIONAL — NOT IMPLEMENTED | Dedicated Gemini calculator prose is optional; it cannot own or modify deterministic quantities. |
| A01 | M: controlled ADMIN access and isolated navigation | COMPLETE AND VERIFIED | Existing implementation and relevant component/security/live regression contracts retained. See the verification ledger for actual provider-run failures and acceptance limits. |
| A02 | M: manage farmers, filters, statuses, session revocation | COMPLETE AND VERIFIED | Existing implementation and relevant component/security/live regression contracts retained. See the verification ledger for actual provider-run failures and acceptance limits. |
| A03 | M: real farmer/scan/today/healthy/disease/activity statistics | COMPLETE AND VERIFIED | Existing implementation and relevant component/security/live regression contracts retained. See the verification ledger for actual provider-run failures and acceptance limits. |
| A04 | M: AI requests and operational service monitoring | COMPLETE AND VERIFIED | Metadata-only real operational producers → ai_operations → ADMIN aggregate API → scoped Flutter cards/charts; bounded loss conditions displayed. |
| A05 | M: model version/health/offline metrics | COMPLETE AND VERIFIED | Existing implementation and relevant component/security/live regression contracts retained. See the verification ledger for actual provider-run failures and acceptance limits. |
| A06 | M/X: manage diseases without changing immutable ML classes | COMPLETE AND VERIFIED | Fixed classifier mapping remains read-only; informational catalogue/display edits are separately validated/audited. |
| A07 | M: create/manage full disease catalogue metadata | PARTIALLY IMPLEMENTED | Sourced informational creation and optional applicability edit/display exist; four trained classes unchanged. Final full-run Farmer reviewed-detail UI assertion fails; focused live pass does not close acceptance. Engineering exists; approved real content also remains pending. |
| A08 | M: knowledge/source review, immutable versions and current retrieval | COMPLETE AND VERIFIED | Existing source-grounded bounded implementation retained; deterministic security/failure tests pass. Actual provider-dependent successes and failures are separately reported, not treated as uniformly successful. |
| A09 | M/L: fertilizer information CRUD and reviewed applicability | COMPLETE WITH APPROVED EXTERNAL CONTENT PENDING | Independent source-reviewed product CRUD, metadata versions, pagination/audit and referenced-product freeze/copy exist. Real agronomic product/context/rate content is absent. |
| A10 | M: configurable sourced units/versions and Admin rule lifecycle | COMPLETE WITH APPROVED EXTERNAL CONTENT PENDING | Existing reviewed executable rules plus disabled richer-model source-intake/versioning; no invented numerical configuration. |
| A11 | M: audit log and Admin viewer | COMPLETE AND VERIFIED | Existing implementation and relevant component/security/live regression contracts retained. See the verification ledger for actual provider-run failures and acceptance limits. |
| A12 | M/L: disease-media management | PARTIALLY IMPLEMENTED | Complete controlled media lifecycle and Farmer gallery; real licensed reference photographs still require approval. Final full-run Farmer reviewed-detail UI assertion fails; focused live pass does not close acceptance. Engineering exists; approved real content also remains pending. |
| ML01 | M/X: one reusable training/serving preprocess implementation | COMPLETE AND VERIFIED | Existing implementation and relevant component/security/live regression contracts retained. See the verification ledger for actual provider-run failures and acceptance limits. |
| ML02 | X: preserve diseased tissue and approved full frame | COMPLETE AND VERIFIED | Existing implementation and relevant component/security/live regression contracts retained. See the verification ledger for actual provider-run failures and acceptance limits. |
| ML03 | M: deterministic eligible/deduplicated grouped split/exclusions | COMPLETE AND VERIFIED | Existing implementation and relevant component/security/live regression contracts retained. See the verification ledger for actual provider-run failures and acceptance limits. |
| ML04 | M: train-only augmentation and no test tuning | COMPLETE AND VERIFIED | Existing implementation and relevant component/security/live regression contracts retained. See the verification ledger for actual provider-run failures and acceptance limits. |
| ML05 | M: experiments, checkpoints, metrics, confusion and per-class analysis | COMPLETE AND VERIFIED | Existing implementation and relevant component/security/live regression contracts retained. See the verification ledger for actual provider-run failures and acceptance limits. |
| ML06 | M: strict once-per-lifespan model load/readiness | COMPLETE AND VERIFIED | Actual saved null-policy configuration starts and loads approved hash-bound artifacts without confidence overrides. |
| ML07 | X/L: no invented confidence threshold/calibration | COMPLETE AND VERIFIED | Approved null threshold/T=1 retained; every result remains LOW_CONFIDENCE/THRESHOLD_UNCONFIGURED until separately approved policy. |
| ML08 | X/L: academic research only, no raw redistribution | COMPLETE AND VERIFIED | Existing implementation and relevant component/security/live regression contracts retained. See the verification ledger for actual provider-run failures and acceptance limits. |
| RAG01 | M: deterministic chunking/versioned configured embeddings/pgvector | PARTIALLY IMPLEMENTED | Existing source-grounded bounded implementation retained; deterministic security/failure tests pass. Actual provider-dependent successes and failures are separately reported, not treated as uniformly successful. Final RAG SQL and retrieval contract fail with database unavailability; exact cause remains open. |
| RAG02 | M: old edits cannot silently retain active stale embeddings | COMPLETE AND VERIFIED | Existing source-grounded bounded implementation retained; deterministic security/failure tests pass. Actual provider-dependent successes and failures are separately reported, not treated as uniformly successful. |
| RAG03 | M/X: factual content stays grounded, controlled Gemini | COMPLETE AND VERIFIED | Existing source-grounded bounded implementation retained; deterministic security/failure tests pass. Actual provider-dependent successes and failures are separately reported, not treated as uniformly successful. |
| N01 | M: Flutter MVVM Provider and Node layering | COMPLETE AND VERIFIED | Existing implementation and relevant component/security/live regression contracts retained. See the verification ledger for actual provider-run failures and acceptance limits. |
| N02 | M: strict types, startup env, validation and safe errors | COMPLETE AND VERIFIED | Existing implementation and relevant component/security/live regression contracts retained. See the verification ledger for actual provider-run failures and acceptance limits. |
| N03 | M: secret isolation, password hashing, JWT/RBAC/rate limits | COMPLETE AND VERIFIED | Existing implementation and relevant component/security/live regression contracts retained. See the verification ledger for actual provider-run failures and acceptance limits. |
| N04 | M: protected ownership and private image handling | COMPLETE AND VERIFIED | Existing implementation and relevant component/security/live regression contracts retained. See the verification ledger for actual provider-run failures and acceptance limits. |
| N05 | M: structured safe request/error/model/timing logs | COMPLETE AND VERIFIED | Existing implementation and relevant component/security/live regression contracts retained. See the verification ledger for actual provider-run failures and acceptance limits. |
| N06 | M: comprehensive automated and cross-service verification | FAILED | Final normal-config run 20261016T204723Z-98b47879: 18 PASS / 3 FAIL / 0 selected skips; failed rag-database, knowledge, predeployment-remediation. Component and focused live passes do not satisfy full-run acceptance. Earlier failures/default opt-in skips remain disclosed. |
| N07 | M: generated Swagger/OpenAPI request/auth/response/error docs | COMPLETE AND VERIFIED | Generated OpenAPI 3.1, 59 actual operations, runtime Zod request schemas/shared checked response contracts, local viewer and drift/coverage/parser checks. |
| N08 | M: production Node/AI/PostgreSQL containers | PARTIALLY IMPLEMENTED | Development PostgreSQL Compose validates. Production service containers/release infrastructure remain expressly unauthorized Phase 25 work, not deferred prior-phase remediation. |
| N09 | M: reproducible pinned environment/templates/configured dataset | COMPLETE AND VERIFIED | Existing implementation and relevant component/security/live regression contracts retained. See the verification ledger for actual provider-run failures and acceptance limits. |
| N10 | M: modular maintainable code, no fake production stubs | COMPLETE AND VERIFIED | Existing implementation and relevant component/security/live regression contracts retained. See the verification ledger for actual provider-run failures and acceptance limits. |
| N11 | M/L: responsive accessible states/targets/text/keyboard | BLOCKED BY ACTUAL EXTERNAL INPUT | Responsive/semantics/widget/large-text checks and ARM64 packaging pass. Physical-device and hosted-browser acceptance require actual targets. |
| N12 | M: meaningful loading/empty/error/retry/cleanup | COMPLETE AND VERIFIED | Committed avatar responses do not await provider cleanup; durable recovery, lost acknowledgements and client reconciliation verified, including 16.5-second delay. |
| N13 | M/L: bounded latency, memory, concurrency and efficient queries | COMPLETE AND VERIFIED | Bounded local admission/queues/latencies and efficient aggregate contracts verified. Production load/SLO proof remains a deployment acceptance gate. |
| N14 | M/L: production TLS/least privilege/privacy/release safety | BLOCKED BY ACTUAL EXTERNAL INPUT | TLS/role/privacy guards pass. Production identity/network provisioning, retention/processing and release approval remain external/deployment gates. |
| N15 | M/L: preserve historical model/experiment outputs | COMPLETE AND VERIFIED | 171 frozen files/checkpoint and original nine migration bytes checked; only five additive migrations, no dataset access/fit/final rescore. |
| N16 | O: exact greeting/educational tip/recent-stat layout examples | OPTIONAL — EXISTING DESIGN RETAINED | Required actions remain reachable. An exact suggested Home greeting/tip placement is not a missing mandatory feature. |

## Phase24.7 current overrides — 2026-10-18

The original65 Phase24.6 rows above are historical. Current repaired-code full
execution passes21/0/0, independent original-boundary repeat4/0/0; all owned
fixtures clean/public counts unchanged. Other scientific/device/release limits
remain unchanged. Whole-phase cause closure is still partial.

| IDs | Current disposition | Exact boundary |
|---|---|---|
| F15/A07 | COMPLETE WITH APPROVED EXTERNAL CONTENT PENDING at workflow level | Real Admin/Node/DB/Farmer reviewed synthetic applicability passes full/repeat. No real stage/severity facts invented. Original heading-timeout cause remains an overall acceptance gap. |
| F16/A12 | COMPLETE WITH APPROVED EXTERNAL CONTENT PENDING at workflow level | Generated reference upload/review/protected gallery/replacement/retirement/cleanup pass. No approved real licensed photos. |
| RAG01 | PARTIALLY IMPLEMENTED for stability acceptance | SQL/vector/version/source and real Google retrieval work; original/later connection attribution remains open. No durable availability claim. |
| N06 | COMPLETE AND VERIFIED for configured automated execution coverage | One current full21/0/0 and independent4/0/0, default skips disclosed. Mandatory original-cause closure/device acceptance are separate unfulfilled gates. |

Overall Phase24.7 PARTIALLY COMPLETE; Phase25 NOT READY. Do not turn feature-level
workflow evidence into whole-FYP/release completion. Richer N/P/K/schedule and
min/expected/potential outputs remain absent; approved mathematical models/data
must precede their exact engine/UI implementation. Current evidence and all
limits: [Phase24.7 report](phase-24-7-integration-stability.md).
