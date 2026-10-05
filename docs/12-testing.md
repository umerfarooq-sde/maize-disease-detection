# Testing Strategy

> **Status:** Required validation baseline; no test suites were present for verification at documentation time.

## Flutter

- Unit-test ViewModels for loading, success, empty, and error transitions.
- Test repositories and API serialization, including authentication and anonymous scan flows.
- Add widget tests for scan submission, result display, retry, and key accessibility states.

## Backend

- Unit-test service rules, ownership checks, RBAC, and error mapping.
- Test repositories against an isolated database or controlled Prisma test setup.
- Add API integration tests for versioned routes, validation, anonymous scans, authenticated history, rate limits, and stable error envelopes.
- Verify that unexpected dependency failures do not produce successful-looking scan results.

## AI service

- Test image validation, decoding, preprocessing stages, invalid inputs, and output tensor contracts.
- Test model readiness, class mapping, output shape, and finite prediction values.
- Test API schemas, timeouts, provider errors, retrieval fallback, and insufficient-evidence responses.
- Test that sensitive content and credentials are not emitted in logs.

## ML pipeline

- Validate dataset integrity, labels, class mapping, and split separation.
- Prove augmentation is applied only to training data.
- Assert training and serving use the same preprocessing implementation and parameters.
- Evaluate held-out metrics, confusion matrix, per-class performance, and artifact compatibility.

## RAG and calculator

- Test source attribution, retrieval filtering, citation fidelity, and weak/no-evidence behavior.
- Evaluate grounded answers using a reviewed test set.
- Unit-test deterministic agricultural calculations independently; verify the language model cannot override numeric results.

## CI and release gates

Run focused tests on changed components, then required full suites before release. Require formatting, linting, static/type checks, migration validation, and integration/contract checks. Record test data and model versions to make results reproducible. Do not use the held-out ML test set for training or repeated tuning.
