# Farmer registration and knowledge library

Phase 23.6 connects the existing authentication and disease-knowledge APIs to Flutter.
No new endpoint, migration, corpus, provider key or model is introduced. See the
[remediation report](phase-23-6-remediation-report.md) for executed verification and
remaining original requirements. This guide supersedes the corresponding unavailable
screens in the historical Phase 5/23/23.5 descriptions.

## Registration

Profile → Sign in → Create a farmer account opens `/profile/register`.
The form collects **email and password only**. There is no role selector or ADMIN
registration path. The registration route owns `RegistrationViewModel`; the root
provides its stateless repository using the same farmer `ApiClient` as sign-in.

```text
RegistrationView → RegistrationViewModel → RegistrationRepository
                → ApiClient → POST /api/v1/auth/register → existing auth service/Prisma
```

Client admission mirrors the installed Zod registration contract: trim/lowercase
email, practical Zod email syntax, maximum 254 characters; Farmer password 6–128 Unicode
code points, unchanged including spaces, with no invented composition requirement.
Operator Admin provisioning retains its separate 15–128-character policy; login,
Argon2id hashing and existing sessions are unchanged.
The backend remains authoritative. Password visibility is ephemeral widget state;
submission, errors and success are ViewModel state. Busy and success guards prevent
accidental repeated submissions. Input remains available for explicit failure retry.

HTTP 201 must contain a matching safe FARMER account projection. HTTP 409 shows an
account-exists/sign-in suggestion; 400/422, rate limits, malformed replies, offline,
timeout and server failures use safe application errors. Raw provider/server text,
passwords and tokens are never displayed or logged. A dropped successful response
can lead to a duplicate-account response on retry; the user can then sign in.

Success clears the password field and offers **Continue to sign in**. Enrollment
does not issue or install credentials, associate old anonymous scans, or authenticate
automatically. Login uses the unchanged session repository. Access tokens and the
restricted refresh cookie remain volatile, refresh remains serialized, and logout
still clears local identity and requests server revocation. No persistent session
storage is added. Registration controllers are disposed when the route closes.

## Knowledge

The Knowledge tab `/knowledge` owns `KnowledgeViewModel`; opening
`/knowledge/:slug` creates a separate `KnowledgeDetailViewModel`. Both use the root
`KnowledgeRepository` dependency and existing Node API client.

| Intent | API | Flutter behavior |
|---|---|---|
| Browse catalogue | `GET /api/v1/diseases` | Active names/descriptions returned by PostgreSQL; no search query is attached |
| Read details | `GET /api/v1/diseases/:slug` | Current published sections and complete source/version metadata |
| Semantic search | `POST /api/v1/knowledge/search` | Explicit submit of `{query, topK:5}`; Node → private FastAPI → Google embeddings → pgvector |

No generated answer or Flutter embedding/retrieval engine is added. Search normalizes
and bounds input using the existing assistant query validator, whose contract is
identical: 3–1000 Unicode code points, at most 1800 UTF-8 bytes, no unreadable C0
controls except newline/tab. Search has a 25-second client deadline above Node's
20-second maximum retrieval deadline; ordinary requests retain 15 seconds.

Results are labeled **Retrieved passages**, with source publisher/URL and document
version, distinct from generated advice or model confidence. Existing literal labels
only select their corresponding catalogue navigation slugs; the classifier mapping
is neither edited nor guessed from display names. Empty results do not hide the
catalogue, and catalogue/network failures do not masquerade as an empty result.

Details render the exact returned title/content/source for each nonempty admitted
section; they do not manufacture headings, images or agricultural paragraphs.
The real four entries are Common Rust, Gray Leaf Spot, Healthy and Northern Corn Leaf
Blight. Healthy currently has four scouting/overview/prevention/reference documents;
the three disease entries have seven each, totaling 25. No Healthy treatment is
invented. Catalogue icons are explicit UI symbols, not photographs of a disease.

`SourceReferenceCard` shares the existing assistant's strict source parser and plain
selectable source presentation: title, publisher, authors, available publication
date, URL, source-check date and rights. It executes no HTML or arbitrary URL handler.
The source's regional/applicability limits remain in the reviewed content.

## State, navigation and accessibility

The indexed farmer shell retains screen-local catalogue/search state across ordinary
tab changes/back navigation. There is **no disk, long-lived active-document or global
knowledge cache**. Detail pages fetch on entry; explicit catalogue/detail refresh
clears prior content before fetching, including when an entry was archived. Public
knowledge is identical for guests/farmers and contains no personal history. A change
of account does not turn public knowledge into private cached account data.

Clearing search fences a late result; disposal fences all outstanding feature
requests. This cancels displayed state, not provider work already underway. Search
does not call providers for every keystroke and is not automatically retried.

The existing safe-area/scrolling page, light theme, error/loading/empty states and
design tokens are reused. Cards bound long description previews while details retain
the complete returned description. The shell hides its brand header/bottom navigation
while a keyboard is open to preserve form space in short landscape layouts; navigation
returns when the keyboard closes. The nested page back button remains available.

## Verification

From `mobile/`:

```powershell
dart format lib test
flutter analyze
flutter test --no-pub test/auth/registration_test.dart test/auth/registration_widget_test.dart test/knowledge
flutter test --no-pub
flutter build apk --debug --no-pub --target-platform android-arm64
```

From root, the opt-in real widget check uses the existing isolation harness:

```powershell
ai-service/.venv/Scripts/python.exe scripts/check-e2e.py --only farmer-remediation
```

It starts real Node/FastAPI, copies the existing sourced corpus to an owned disposable
schema, drives actual registration/login/knowledge widgets, verifies the Argon2id
FARMER row and revoked sessions, drops only that owned schema, and compares all 21
production table counts. Flutter receives only SDK environment values, public Node
URL and generated fixture credentials. No server key/database URL enters the test
child. No new knowledge, cloud asset, recommendation, raw dataset access or ML fitting
is needed. Default suites explicitly skip the live check unless enabled by this harness.

Host widget and API verification is **not physical Android interaction**. Camera,
platform permissions, real keyboard/IME/device behavior and release acceptance still
require the separately scheduled device testing.
