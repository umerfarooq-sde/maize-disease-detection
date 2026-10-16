-- No prompt, transcript, credential, image, user or scan identifiers are retained.
CREATE TABLE "ai_operations" (
  "id" uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  "scope" varchar(20) NOT NULL CHECK (scope IN ('NODE', 'AI_SERVICE', 'PROVIDER')),
  "operation" varchar(24) NOT NULL CHECK (operation IN ('INFERENCE', 'RETRIEVAL', 'GENERATION', 'EXPLANATION', 'GEMINI', 'EMBEDDING')),
  "outcome" varchar(20) NOT NULL CHECK (outcome IN ('SUCCESS', 'FAILED', 'ABSTAINED')),
  "duration_ms" integer NOT NULL CHECK (duration_ms BETWEEN 0 AND 86400000),
  "category" varchar(24) CHECK (category IN ('TIMEOUT', 'REJECTED', 'UNAVAILABLE', 'INVALID_RESPONSE', 'INTERNAL')),
  "occurred_at" timestamptz(6) NOT NULL DEFAULT now()
);
CREATE INDEX "ai_operations_occurred_at_scope_operation_idx" ON "ai_operations"("occurred_at", "scope", "operation");
