# Deployment

> **Status:** Deployment requirements baseline; target hosting platform and actual configuration are not yet specified.

## Deployable units

- Flutter mobile app distributed through the chosen platform channels.
- Node.js/TypeScript backend API.
- Python/FastAPI AI service with a compatible immutable model artifact.
- PostgreSQL database and migrations.
- Cloudinary account/configuration for image assets.
- Gemini credentials and knowledge/retrieval resources where enabled.

## Environment configuration

Separate development, staging, and production configuration. Inject secrets through environment or a secret manager. Typical configuration includes database connection, JWT keys, Cloudinary credentials, internal AI-service URL/authentication, Gemini credentials, upload limits, timeouts, and model artifact/version. Never bundle secrets in the mobile app or repository.

## Build and release

Build backend and AI service as reproducible artifacts with locked dependencies. Pin model and preprocessing versions. Apply reviewed database migrations as a controlled release step with backup and rollback planning. Promote an immutable model artifact only after evaluation and compatibility checks; retain the prior production artifact for rollback.

## Health and scaling

Provide liveness and readiness checks. AI readiness should verify the expected model is loaded and required dependencies are available. Configure resource limits and concurrency based on measured image/model memory and latency. Scale API and AI workers independently where supported.

## Operations

- Use TLS at external boundaries and restrict internal service networking.
- Monitor request volume, error rates, latency, dependency timeouts, model readiness, and storage usage.
- Propagate request IDs while excluding tokens, image content, and secrets from logs.
- Establish backups, restore drills, retention/deletion workflows, and incident response.
- Document deployment-specific alarms, ownership, and rollback procedures before production release.

## Outstanding decisions

Select hosting/provider, regions and data residency, container/runtime strategy, CI/CD, secrets management, scaling targets, recovery objectives, and mobile API environment configuration. Validate those choices against privacy, agricultural operating conditions, and available connectivity.
