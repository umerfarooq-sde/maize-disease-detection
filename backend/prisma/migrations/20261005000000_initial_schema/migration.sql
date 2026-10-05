-- All DDL is atomic: a failure must not leave a partially installed schema.
BEGIN;
CREATE EXTENSION IF NOT EXISTS vector WITH SCHEMA public;

-- CreateSchema
CREATE SCHEMA IF NOT EXISTS "public";

-- CreateEnum
CREATE TYPE "UserRole" AS ENUM ('FARMER', 'ADMIN');

-- CreateEnum
CREATE TYPE "UserStatus" AS ENUM ('ACTIVE', 'SUSPENDED', 'DEACTIVATED');

-- CreateEnum
CREATE TYPE "RecordStatus" AS ENUM ('DRAFT', 'ACTIVE', 'INACTIVE');

-- CreateEnum
CREATE TYPE "DiseaseSeverity" AS ENUM ('LOW', 'MODERATE', 'HIGH');

-- CreateEnum
CREATE TYPE "ScanStatus" AS ENUM ('PENDING', 'PROCESSING', 'COMPLETED', 'FAILED');

-- CreateEnum
CREATE TYPE "KnowledgeStatus" AS ENUM ('DRAFT', 'ACTIVE', 'ARCHIVED');

-- CreateEnum
CREATE TYPE "KnowledgeTopic" AS ENUM ('DISEASE', 'FERTILIZER', 'CALCULATOR', 'GENERAL');

-- CreateEnum
CREATE TYPE "EmbeddingStatus" AS ENUM ('PENDING', 'READY', 'FAILED');

-- CreateEnum
CREATE TYPE "CalculatorKind" AS ENUM ('FERTILIZER', 'YIELD');

-- CreateEnum
CREATE TYPE "ModelStatus" AS ENUM ('DRAFT', 'VALIDATED', 'PRODUCTION', 'RETIRED');

-- CreateEnum
CREATE TYPE "MetricSplit" AS ENUM ('TRAIN', 'VALIDATION', 'TEST');

-- CreateEnum
CREATE TYPE "AiQueryKind" AS ENUM ('GENERAL', 'DISEASE', 'FERTILIZER', 'YIELD');

-- CreateEnum
CREATE TYPE "AiQueryStatus" AS ENUM ('PENDING', 'COMPLETED', 'FAILED');

-- CreateEnum
CREATE TYPE "AiResponseStatus" AS ENUM ('GROUNDED', 'INSUFFICIENT_INFORMATION', 'FAILED');

-- CreateEnum
CREATE TYPE "AuditAction" AS ENUM ('CREATE', 'UPDATE', 'ACTIVATE', 'DEACTIVATE', 'DELETE', 'MODEL_PROMOTION');

-- CreateEnum
CREATE TYPE "NotificationKind" AS ENUM ('SYSTEM', 'SCAN_READY', 'KNOWLEDGE_UPDATE');

-- CreateEnum
CREATE TYPE "HistoryKind" AS ENUM ('SCAN', 'AI_QUESTION', 'FERTILIZER_CALCULATION', 'YIELD_CALCULATION');

-- CreateTable
CREATE TABLE "users" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "email" VARCHAR(254) NOT NULL,
    "password_hash" VARCHAR(255) NOT NULL,
    "role" "UserRole" NOT NULL DEFAULT 'FARMER',
    "status" "UserStatus" NOT NULL DEFAULT 'ACTIVE',
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "users_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "farmer_profiles" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "user_id" UUID NOT NULL,
    "display_name" VARCHAR(120) NOT NULL,
    "phone" VARCHAR(32),
    "region" VARCHAR(120),
    "country_code" CHAR(2),
    "field_area_hectares" DECIMAL(12,4),
    "avatar_url" TEXT,
    "avatar_public_id" VARCHAR(255),
    "preferred_language" VARCHAR(16) NOT NULL DEFAULT 'en',
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "farmer_profiles_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "diseases" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "slug" VARCHAR(120) NOT NULL,
    "name" VARCHAR(160) NOT NULL,
    "scientific_name" VARCHAR(200),
    "description" TEXT NOT NULL,
    "symptoms" TEXT[] DEFAULT ARRAY[]::TEXT[],
    "causes" TEXT[] DEFAULT ARRAY[]::TEXT[],
    "treatments" TEXT[] DEFAULT ARRAY[]::TEXT[],
    "precautions" TEXT[] DEFAULT ARRAY[]::TEXT[],
    "favorable_conditions" TEXT[] DEFAULT ARRAY[]::TEXT[],
    "affected_growth_stages" TEXT[] DEFAULT ARRAY[]::TEXT[],
    "severity" "DiseaseSeverity",
    "status" "RecordStatus" NOT NULL DEFAULT 'DRAFT',
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "diseases_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "disease_images" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "disease_id" UUID NOT NULL,
    "image_url" TEXT NOT NULL,
    "cloudinary_public_id" VARCHAR(255) NOT NULL,
    "alt_text" VARCHAR(255) NOT NULL,
    "sort_order" INTEGER NOT NULL DEFAULT 0,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "disease_images_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "disease_sources" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "disease_id" UUID NOT NULL,
    "title" VARCHAR(255) NOT NULL,
    "url" TEXT,
    "citation" TEXT,
    "publisher" VARCHAR(255),
    "published_at" DATE,
    "status" "RecordStatus" NOT NULL DEFAULT 'DRAFT',
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "disease_sources_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "scans" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "user_id" UUID,
    "image_url" TEXT NOT NULL,
    "cloudinary_public_id" VARCHAR(255) NOT NULL,
    "image_mime_type" VARCHAR(64) NOT NULL,
    "image_bytes" INTEGER NOT NULL,
    "status" "ScanStatus" NOT NULL DEFAULT 'PENDING',
    "processing_time_ms" INTEGER,
    "error_code" VARCHAR(64),
    "finished_at" TIMESTAMPTZ(6),
    "expires_at" TIMESTAMPTZ(6),
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "scans_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "scan_predictions" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "scan_id" UUID NOT NULL,
    "model_version_id" UUID NOT NULL,
    "disease_id" UUID,
    "predicted_class" VARCHAR(120) NOT NULL,
    "confidence" DOUBLE PRECISION NOT NULL,
    "probabilities" JSONB NOT NULL,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "scan_predictions_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "knowledge_documents" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "document_key" VARCHAR(160) NOT NULL,
    "version" INTEGER NOT NULL,
    "title" VARCHAR(255) NOT NULL,
    "content" TEXT NOT NULL,
    "content_hash" CHAR(64) NOT NULL,
    "source_reference" TEXT NOT NULL,
    "topic" "KnowledgeTopic" NOT NULL,
    "language" VARCHAR(16) NOT NULL DEFAULT 'en',
    "status" "KnowledgeStatus" NOT NULL DEFAULT 'DRAFT',
    "disease_id" UUID,
    "fertilizer_id" UUID,
    "created_by_id" UUID,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "knowledge_documents_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "knowledge_chunks" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "document_id" UUID NOT NULL,
    "chunk_index" INTEGER NOT NULL,
    "content" TEXT NOT NULL,
    "content_hash" CHAR(64) NOT NULL,
    "token_count" INTEGER,
    "embedding" public.vector,
    "embedding_model" VARCHAR(160),
    "embedding_dimensions" INTEGER,
    "embedding_status" "EmbeddingStatus" NOT NULL DEFAULT 'PENDING',
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "knowledge_chunks_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "fertilizers" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "slug" VARCHAR(120) NOT NULL,
    "name" VARCHAR(160) NOT NULL,
    "description" TEXT NOT NULL,
    "nitrogen_percent" DECIMAL(5,2) NOT NULL,
    "phosphorus_percent" DECIMAL(5,2) NOT NULL,
    "potassium_percent" DECIMAL(5,2) NOT NULL,
    "application_method" TEXT,
    "precautions" TEXT[] DEFAULT ARRAY[]::TEXT[],
    "source_reference" TEXT NOT NULL,
    "status" "RecordStatus" NOT NULL DEFAULT 'DRAFT',
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "fertilizers_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "fertilizer_rules" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "fertilizer_id" UUID NOT NULL,
    "rule_key" VARCHAR(120) NOT NULL,
    "version" INTEGER NOT NULL,
    "growth_stage" VARCHAR(80),
    "parameters" JSONB NOT NULL,
    "unit" VARCHAR(80) NOT NULL,
    "source_reference" TEXT NOT NULL,
    "status" "RecordStatus" NOT NULL DEFAULT 'DRAFT',
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "fertilizer_rules_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "calculator_configs" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "kind" "CalculatorKind" NOT NULL,
    "config_key" VARCHAR(120) NOT NULL,
    "version" INTEGER NOT NULL,
    "parameters" JSONB NOT NULL,
    "unit" VARCHAR(80) NOT NULL,
    "source_reference" TEXT NOT NULL,
    "status" "RecordStatus" NOT NULL DEFAULT 'DRAFT',
    "created_by_id" UUID,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "calculator_configs_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "model_versions" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "version" VARCHAR(80) NOT NULL,
    "architecture" VARCHAR(120) NOT NULL,
    "artifact_uri" TEXT NOT NULL,
    "artifact_sha256" CHAR(64) NOT NULL,
    "dataset_version" VARCHAR(120) NOT NULL,
    "preprocessing_version" VARCHAR(120) NOT NULL,
    "class_labels" TEXT[],
    "training_config" JSONB NOT NULL,
    "status" "ModelStatus" NOT NULL DEFAULT 'DRAFT',
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "model_versions_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "model_metrics" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "model_version_id" UUID NOT NULL,
    "split" "MetricSplit" NOT NULL,
    "dataset_version" VARCHAR(120) NOT NULL,
    "sample_count" INTEGER NOT NULL,
    "accuracy" DOUBLE PRECISION NOT NULL,
    "precision" DOUBLE PRECISION NOT NULL,
    "recall" DOUBLE PRECISION NOT NULL,
    "f1" DOUBLE PRECISION NOT NULL,
    "loss" DOUBLE PRECISION,
    "confusion_matrix" JSONB NOT NULL,
    "per_class_metrics" JSONB NOT NULL,
    "learning_curves" JSONB NOT NULL DEFAULT '{}',
    "evaluated_at" TIMESTAMPTZ(6) NOT NULL,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "model_metrics_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "ai_queries" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "user_id" UUID,
    "scan_id" UUID,
    "disease_id" UUID,
    "kind" "AiQueryKind" NOT NULL DEFAULT 'GENERAL',
    "question" TEXT NOT NULL,
    "status" "AiQueryStatus" NOT NULL DEFAULT 'PENDING',
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "ai_queries_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "ai_responses" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "query_id" UUID NOT NULL,
    "status" "AiResponseStatus" NOT NULL,
    "answer" TEXT NOT NULL,
    "provider_model" VARCHAR(160) NOT NULL,
    "citations" JSONB NOT NULL DEFAULT '[]',
    "processing_ms" INTEGER NOT NULL,
    "input_tokens" INTEGER,
    "output_tokens" INTEGER,
    "error_code" VARCHAR(64),
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "ai_responses_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "audit_logs" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "actor_id" UUID,
    "action" "AuditAction" NOT NULL,
    "entity_type" VARCHAR(80) NOT NULL,
    "entity_id" UUID NOT NULL,
    "request_id" VARCHAR(128),
    "changes" JSONB NOT NULL DEFAULT '{}',
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "audit_logs_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "notifications" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "user_id" UUID NOT NULL,
    "scan_id" UUID,
    "kind" "NotificationKind" NOT NULL DEFAULT 'SYSTEM',
    "title" VARCHAR(160) NOT NULL,
    "message" TEXT NOT NULL,
    "read_at" TIMESTAMPTZ(6),
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "notifications_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "history" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "user_id" UUID NOT NULL,
    "kind" "HistoryKind" NOT NULL,
    "scan_id" UUID,
    "ai_query_id" UUID,
    "calculator_config_id" UUID,
    "snapshot" JSONB NOT NULL DEFAULT '{}',
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "history_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "users_email_key" ON "users"("email");

-- CreateIndex
CREATE INDEX "users_role_status_created_at_idx" ON "users"("role", "status", "created_at");

-- CreateIndex
CREATE UNIQUE INDEX "farmer_profiles_user_id_key" ON "farmer_profiles"("user_id");

-- CreateIndex
CREATE UNIQUE INDEX "farmer_profiles_avatar_public_id_key" ON "farmer_profiles"("avatar_public_id");

-- CreateIndex
CREATE UNIQUE INDEX "diseases_slug_key" ON "diseases"("slug");

-- CreateIndex
CREATE INDEX "diseases_status_name_idx" ON "diseases"("status", "name");

-- CreateIndex
CREATE UNIQUE INDEX "disease_images_cloudinary_public_id_key" ON "disease_images"("cloudinary_public_id");

-- CreateIndex
CREATE INDEX "disease_images_disease_id_sort_order_idx" ON "disease_images"("disease_id", "sort_order");

-- CreateIndex
CREATE INDEX "disease_sources_disease_id_status_idx" ON "disease_sources"("disease_id", "status");

-- CreateIndex
CREATE UNIQUE INDEX "scans_cloudinary_public_id_key" ON "scans"("cloudinary_public_id");

-- CreateIndex
CREATE INDEX "scans_user_id_created_at_idx" ON "scans"("user_id", "created_at" DESC);

-- CreateIndex
CREATE INDEX "scans_status_created_at_idx" ON "scans"("status", "created_at");

-- CreateIndex
CREATE INDEX "scans_expires_at_idx" ON "scans"("expires_at");

-- CreateIndex
CREATE UNIQUE INDEX "scans_id_user_id_key" ON "scans"("id", "user_id");

-- CreateIndex
CREATE INDEX "scan_predictions_model_version_id_created_at_idx" ON "scan_predictions"("model_version_id", "created_at");

-- CreateIndex
CREATE INDEX "scan_predictions_disease_id_created_at_idx" ON "scan_predictions"("disease_id", "created_at");

-- CreateIndex
CREATE UNIQUE INDEX "scan_predictions_scan_id_model_version_id_key" ON "scan_predictions"("scan_id", "model_version_id");

-- CreateIndex
CREATE INDEX "knowledge_documents_status_topic_language_idx" ON "knowledge_documents"("status", "topic", "language");

-- CreateIndex
CREATE INDEX "knowledge_documents_disease_id_idx" ON "knowledge_documents"("disease_id");

-- CreateIndex
CREATE INDEX "knowledge_documents_fertilizer_id_idx" ON "knowledge_documents"("fertilizer_id");

-- CreateIndex
CREATE INDEX "knowledge_documents_created_by_id_idx" ON "knowledge_documents"("created_by_id");

-- CreateIndex
CREATE UNIQUE INDEX "knowledge_documents_document_key_version_key" ON "knowledge_documents"("document_key", "version");

-- CreateIndex
CREATE INDEX "knowledge_chunks_embedding_status_embedding_model_idx" ON "knowledge_chunks"("embedding_status", "embedding_model");

-- CreateIndex
CREATE UNIQUE INDEX "knowledge_chunks_document_id_chunk_index_key" ON "knowledge_chunks"("document_id", "chunk_index");

-- CreateIndex
CREATE UNIQUE INDEX "fertilizers_slug_key" ON "fertilizers"("slug");

-- CreateIndex
CREATE INDEX "fertilizers_status_name_idx" ON "fertilizers"("status", "name");

-- CreateIndex
CREATE INDEX "fertilizer_rules_status_growth_stage_idx" ON "fertilizer_rules"("status", "growth_stage");

-- CreateIndex
CREATE UNIQUE INDEX "fertilizer_rules_fertilizer_id_rule_key_version_key" ON "fertilizer_rules"("fertilizer_id", "rule_key", "version");

-- CreateIndex
CREATE INDEX "calculator_configs_kind_status_idx" ON "calculator_configs"("kind", "status");

-- CreateIndex
CREATE INDEX "calculator_configs_created_by_id_idx" ON "calculator_configs"("created_by_id");

-- CreateIndex
CREATE UNIQUE INDEX "calculator_configs_kind_config_key_version_key" ON "calculator_configs"("kind", "config_key", "version");

-- CreateIndex
CREATE UNIQUE INDEX "model_versions_version_key" ON "model_versions"("version");

-- CreateIndex
CREATE UNIQUE INDEX "model_versions_artifact_uri_key" ON "model_versions"("artifact_uri");

-- CreateIndex
CREATE INDEX "model_versions_status_created_at_idx" ON "model_versions"("status", "created_at");

-- CreateIndex
CREATE UNIQUE INDEX "model_metrics_model_version_id_split_evaluated_at_key" ON "model_metrics"("model_version_id", "split", "evaluated_at");

-- CreateIndex
CREATE INDEX "ai_queries_user_id_created_at_idx" ON "ai_queries"("user_id", "created_at" DESC);

-- CreateIndex
CREATE INDEX "ai_queries_scan_id_idx" ON "ai_queries"("scan_id");

-- CreateIndex
CREATE INDEX "ai_queries_disease_id_idx" ON "ai_queries"("disease_id");

-- CreateIndex
CREATE INDEX "ai_queries_status_created_at_idx" ON "ai_queries"("status", "created_at");

-- CreateIndex
CREATE UNIQUE INDEX "ai_queries_id_user_id_key" ON "ai_queries"("id", "user_id");

-- CreateIndex
CREATE INDEX "ai_responses_query_id_created_at_idx" ON "ai_responses"("query_id", "created_at");

-- CreateIndex
CREATE INDEX "audit_logs_actor_id_created_at_idx" ON "audit_logs"("actor_id", "created_at" DESC);

-- CreateIndex
CREATE INDEX "audit_logs_entity_type_entity_id_created_at_idx" ON "audit_logs"("entity_type", "entity_id", "created_at");

-- CreateIndex
CREATE INDEX "notifications_user_id_read_at_created_at_idx" ON "notifications"("user_id", "read_at", "created_at" DESC);

-- CreateIndex
CREATE INDEX "notifications_scan_id_user_id_idx" ON "notifications"("scan_id", "user_id");

-- CreateIndex
CREATE UNIQUE INDEX "history_scan_id_key" ON "history"("scan_id");

-- CreateIndex
CREATE UNIQUE INDEX "history_ai_query_id_key" ON "history"("ai_query_id");

-- CreateIndex
CREATE INDEX "history_user_id_created_at_idx" ON "history"("user_id", "created_at" DESC);

-- CreateIndex
CREATE INDEX "history_calculator_config_id_idx" ON "history"("calculator_config_id");

-- AddForeignKey
ALTER TABLE "farmer_profiles" ADD CONSTRAINT "farmer_profiles_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "disease_images" ADD CONSTRAINT "disease_images_disease_id_fkey" FOREIGN KEY ("disease_id") REFERENCES "diseases"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "disease_sources" ADD CONSTRAINT "disease_sources_disease_id_fkey" FOREIGN KEY ("disease_id") REFERENCES "diseases"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "scans" ADD CONSTRAINT "scans_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "scan_predictions" ADD CONSTRAINT "scan_predictions_scan_id_fkey" FOREIGN KEY ("scan_id") REFERENCES "scans"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "scan_predictions" ADD CONSTRAINT "scan_predictions_model_version_id_fkey" FOREIGN KEY ("model_version_id") REFERENCES "model_versions"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "scan_predictions" ADD CONSTRAINT "scan_predictions_disease_id_fkey" FOREIGN KEY ("disease_id") REFERENCES "diseases"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "knowledge_documents" ADD CONSTRAINT "knowledge_documents_disease_id_fkey" FOREIGN KEY ("disease_id") REFERENCES "diseases"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "knowledge_documents" ADD CONSTRAINT "knowledge_documents_fertilizer_id_fkey" FOREIGN KEY ("fertilizer_id") REFERENCES "fertilizers"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "knowledge_documents" ADD CONSTRAINT "knowledge_documents_created_by_id_fkey" FOREIGN KEY ("created_by_id") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "knowledge_chunks" ADD CONSTRAINT "knowledge_chunks_document_id_fkey" FOREIGN KEY ("document_id") REFERENCES "knowledge_documents"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "fertilizer_rules" ADD CONSTRAINT "fertilizer_rules_fertilizer_id_fkey" FOREIGN KEY ("fertilizer_id") REFERENCES "fertilizers"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "calculator_configs" ADD CONSTRAINT "calculator_configs_created_by_id_fkey" FOREIGN KEY ("created_by_id") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "model_metrics" ADD CONSTRAINT "model_metrics_model_version_id_fkey" FOREIGN KEY ("model_version_id") REFERENCES "model_versions"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ai_queries" ADD CONSTRAINT "ai_queries_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ai_queries" ADD CONSTRAINT "ai_queries_scan_id_fkey" FOREIGN KEY ("scan_id") REFERENCES "scans"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ai_queries" ADD CONSTRAINT "ai_queries_disease_id_fkey" FOREIGN KEY ("disease_id") REFERENCES "diseases"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ai_responses" ADD CONSTRAINT "ai_responses_query_id_fkey" FOREIGN KEY ("query_id") REFERENCES "ai_queries"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "audit_logs" ADD CONSTRAINT "audit_logs_actor_id_fkey" FOREIGN KEY ("actor_id") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "notifications" ADD CONSTRAINT "notifications_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "notifications" ADD CONSTRAINT "notifications_scan_id_user_id_fkey" FOREIGN KEY ("scan_id", "user_id") REFERENCES "scans"("id", "user_id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "history" ADD CONSTRAINT "history_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "history" ADD CONSTRAINT "history_scan_id_user_id_fkey" FOREIGN KEY ("scan_id", "user_id") REFERENCES "scans"("id", "user_id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "history" ADD CONSTRAINT "history_ai_query_id_user_id_fkey" FOREIGN KEY ("ai_query_id", "user_id") REFERENCES "ai_queries"("id", "user_id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "history" ADD CONSTRAINT "history_calculator_config_id_fkey" FOREIGN KEY ("calculator_config_id") REFERENCES "calculator_configs"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- PostgreSQL invariants that Prisma's schema language cannot express.
ALTER TABLE users ADD CONSTRAINT users_identity_check CHECK (
    email = lower(btrim(email)) AND email ~ '^[^[:space:]@]+@[^[:space:]@]+$'
    AND length(btrim(password_hash)) > 0
);
ALTER TABLE farmer_profiles ADD CONSTRAINT farmer_profiles_values_check CHECK (
    length(btrim(display_name)) > 0 AND length(btrim(preferred_language)) > 0
    AND (field_area_hectares IS NULL OR field_area_hectares > 0)
    AND (country_code IS NULL OR country_code ~ '^[A-Z]{2}$')
    AND ((avatar_url IS NULL) = (avatar_public_id IS NULL))
);
ALTER TABLE diseases ADD CONSTRAINT diseases_content_check CHECK (
    slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$' AND length(btrim(name)) > 0
    AND length(btrim(description)) > 0 AND symptoms IS NOT NULL AND causes IS NOT NULL
    AND treatments IS NOT NULL AND precautions IS NOT NULL AND favorable_conditions IS NOT NULL
    AND affected_growth_stages IS NOT NULL
);
ALTER TABLE disease_images ADD CONSTRAINT disease_images_values_check CHECK (
    sort_order >= 0 AND length(btrim(image_url)) > 0
    AND length(btrim(cloudinary_public_id)) > 0 AND length(btrim(alt_text)) > 0
);
ALTER TABLE disease_sources ADD CONSTRAINT disease_sources_provenance_check CHECK (
    length(btrim(title)) > 0
    AND (coalesce(length(btrim(url)), 0) > 0 OR coalesce(length(btrim(citation)), 0) > 0)
);
ALTER TABLE scans ADD CONSTRAINT scans_values_check CHECK (
    image_bytes > 0 AND image_mime_type IN ('image/jpeg', 'image/png', 'image/webp')
    AND length(btrim(image_url)) > 0 AND length(btrim(cloudinary_public_id)) > 0
    AND (processing_time_ms IS NULL OR processing_time_ms >= 0)
    AND ((status IN ('COMPLETED', 'FAILED')) = (finished_at IS NOT NULL))
    AND ((status = 'FAILED') = (error_code IS NOT NULL))
    AND (error_code IS NULL OR length(btrim(error_code)) > 0)
    AND (finished_at IS NULL OR finished_at >= created_at)
    AND (expires_at IS NULL OR expires_at > created_at)
);

CREATE FUNCTION valid_class_labels(labels text[]) RETURNS boolean
LANGUAGE sql IMMUTABLE STRICT AS $$
    SELECT cardinality(labels) >= 2
       AND cardinality(labels) = (SELECT count(DISTINCT label) FROM unnest(labels) AS label)
       AND NOT EXISTS (SELECT 1 FROM unnest(labels) AS label WHERE label IS NULL OR btrim(label) = '')
$$;
ALTER TABLE model_versions ADD CONSTRAINT model_versions_metadata_check CHECK (
    length(btrim(version)) > 0 AND length(btrim(architecture)) > 0
    AND length(btrim(artifact_uri)) > 0 AND artifact_sha256 ~ '^[0-9a-f]{64}$'
    AND length(btrim(dataset_version)) > 0 AND length(btrim(preprocessing_version)) > 0
    AND class_labels IS NOT NULL AND valid_class_labels(class_labels) AND jsonb_typeof(training_config) = 'object'
);

CREATE FUNCTION valid_probabilities(probabilities jsonb) RETURNS boolean
LANGUAGE plpgsql IMMUTABLE STRICT AS $$
DECLARE item record; total numeric := 0; entries integer := 0; value numeric;
BEGIN
    IF jsonb_typeof(probabilities) <> 'object' THEN RETURN false; END IF;
    FOR item IN SELECT * FROM jsonb_each(probabilities) LOOP
        IF jsonb_typeof(item.value) <> 'number' THEN RETURN false; END IF;
        value := (item.value #>> '{}')::numeric;
        IF NOT (value BETWEEN 0 AND 1) THEN RETURN false; END IF;
        total := total + value;
        entries := entries + 1;
    END LOOP;
    RETURN entries > 0 AND abs(total - 1) <= 0.00001;
END $$;
ALTER TABLE scan_predictions ADD CONSTRAINT scan_predictions_values_check CHECK (
    confidence BETWEEN 0 AND 1 AND length(btrim(predicted_class)) > 0
    AND valid_probabilities(probabilities)
);
ALTER TABLE knowledge_documents ADD CONSTRAINT knowledge_documents_content_check CHECK (
    version > 0 AND length(btrim(document_key)) > 0 AND length(btrim(title)) > 0
    AND length(btrim(content)) > 0 AND length(btrim(source_reference)) > 0
    AND length(btrim(language)) > 0
    AND content_hash = encode(sha256(convert_to(content, 'UTF8')), 'hex')
);
ALTER TABLE knowledge_chunks ADD CONSTRAINT knowledge_chunks_content_check CHECK (
    chunk_index >= 0 AND length(btrim(content)) > 0
    AND content_hash = encode(sha256(convert_to(content, 'UTF8')), 'hex')
    AND (token_count IS NULL OR token_count >= 0)
    AND (embedding_dimensions IS NULL OR embedding_dimensions > 0)
    AND (embedding_model IS NULL OR length(btrim(embedding_model)) > 0)
    AND (embedding IS NULL OR (embedding_dimensions IS NOT NULL
         AND embedding_model IS NOT NULL AND public.vector_dims(embedding) = embedding_dimensions))
    AND ((embedding_status = 'READY') = (embedding IS NOT NULL))
);
-- Label convention: nitrogen N, phosphorus P2O5, potassium K2O, each percent by mass.
-- Oxide-equivalent percentages must not be constrained by an elemental sum rule.
ALTER TABLE fertilizers ADD CONSTRAINT fertilizers_values_check CHECK (
    slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$' AND length(btrim(name)) > 0
    AND length(btrim(description)) > 0 AND length(btrim(source_reference)) > 0 AND precautions IS NOT NULL
    AND nitrogen_percent BETWEEN 0 AND 100 AND phosphorus_percent BETWEEN 0 AND 100
    AND potassium_percent BETWEEN 0 AND 100
);
ALTER TABLE fertilizer_rules ADD CONSTRAINT fertilizer_rules_values_check CHECK (
    version > 0 AND length(btrim(rule_key)) > 0 AND length(btrim(unit)) > 0
    AND length(btrim(source_reference)) > 0 AND jsonb_typeof(parameters) = 'object'
);
ALTER TABLE calculator_configs ADD CONSTRAINT calculator_configs_values_check CHECK (
    version > 0 AND length(btrim(config_key)) > 0 AND length(btrim(unit)) > 0
    AND length(btrim(source_reference)) > 0 AND jsonb_typeof(parameters) = 'object'
);
ALTER TABLE model_metrics ADD CONSTRAINT model_metrics_values_check CHECK (
    sample_count > 0 AND length(btrim(dataset_version)) > 0
    AND accuracy BETWEEN 0 AND 1 AND precision BETWEEN 0 AND 1
    AND recall BETWEEN 0 AND 1 AND f1 BETWEEN 0 AND 1
    AND (loss IS NULL OR (loss >= 0 AND loss < 'Infinity'::double precision))
    AND jsonb_typeof(confusion_matrix) = 'array' AND jsonb_typeof(per_class_metrics) = 'object'
    AND jsonb_typeof(learning_curves) = 'object'
);
ALTER TABLE ai_queries ADD CONSTRAINT ai_queries_question_check CHECK (
    length(btrim(question)) BETWEEN 1 AND 8000
);
ALTER TABLE ai_responses ADD CONSTRAINT ai_responses_values_check CHECK (
    length(btrim(answer)) > 0 AND length(btrim(provider_model)) > 0
    AND jsonb_typeof(citations) = 'array'
    AND (status <> 'GROUNDED' OR jsonb_array_length(citations) > 0)
    AND processing_ms >= 0 AND (input_tokens IS NULL OR input_tokens >= 0)
    AND (output_tokens IS NULL OR output_tokens >= 0)
    AND ((status = 'FAILED') = (error_code IS NOT NULL))
    AND (error_code IS NULL OR length(btrim(error_code)) > 0)
);
ALTER TABLE audit_logs ADD CONSTRAINT audit_logs_values_check CHECK (
    length(btrim(entity_type)) > 0 AND jsonb_typeof(changes) = 'object'
);
ALTER TABLE notifications ADD CONSTRAINT notifications_values_check CHECK (
    length(btrim(title)) > 0 AND length(btrim(message)) > 0
    AND (kind <> 'SCAN_READY' OR scan_id IS NOT NULL)
    AND (read_at IS NULL OR read_at >= created_at)
);
ALTER TABLE history ADD CONSTRAINT history_target_check CHECK (
    jsonb_typeof(snapshot) = 'object' AND (
        (kind = 'SCAN' AND scan_id IS NOT NULL AND ai_query_id IS NULL AND calculator_config_id IS NULL)
        OR (kind = 'AI_QUESTION' AND ai_query_id IS NOT NULL AND scan_id IS NULL AND calculator_config_id IS NULL)
        OR (kind IN ('FERTILIZER_CALCULATION', 'YIELD_CALCULATION')
            AND calculator_config_id IS NOT NULL AND scan_id IS NULL AND ai_query_id IS NULL)
    )
);

CREATE UNIQUE INDEX knowledge_documents_one_active_idx ON knowledge_documents(document_key) WHERE status = 'ACTIVE';
CREATE UNIQUE INDEX fertilizer_rules_one_active_idx ON fertilizer_rules(fertilizer_id, rule_key) WHERE status = 'ACTIVE';
CREATE UNIQUE INDEX calculator_configs_one_active_idx ON calculator_configs(kind, config_key) WHERE status = 'ACTIVE';
CREATE UNIQUE INDEX model_versions_one_production_idx ON model_versions((status)) WHERE status = 'PRODUCTION';

-- Preserve provenance and ownership while allowing explicitly mutable lifecycle fields.
CREATE FUNCTION protect_record_fields() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
    IF (to_jsonb(NEW) - TG_ARGV) IS DISTINCT FROM (to_jsonb(OLD) - TG_ARGV) THEN
        RAISE EXCEPTION 'Immutable fields cannot be updated in %; create a new version or record', TG_TABLE_NAME
            USING ERRCODE = '23514';
    END IF;
    RETURN NEW;
END $$;
CREATE TRIGGER scans_protect_identity BEFORE UPDATE ON scans FOR EACH ROW
    EXECUTE FUNCTION protect_record_fields('status', 'processing_time_ms', 'error_code', 'finished_at', 'expires_at', 'updated_at');
CREATE TRIGGER model_versions_protect_version BEFORE UPDATE ON model_versions FOR EACH ROW
    EXECUTE FUNCTION protect_record_fields('status', 'updated_at');
CREATE TRIGGER knowledge_documents_protect_version BEFORE UPDATE ON knowledge_documents FOR EACH ROW
    EXECUTE FUNCTION protect_record_fields('status', 'created_by_id', 'updated_at');
CREATE TRIGGER knowledge_chunks_protect_content BEFORE UPDATE ON knowledge_chunks FOR EACH ROW
    EXECUTE FUNCTION protect_record_fields('token_count', 'embedding', 'embedding_model', 'embedding_dimensions', 'embedding_status', 'updated_at');
CREATE TRIGGER fertilizer_rules_protect_version BEFORE UPDATE ON fertilizer_rules FOR EACH ROW
    EXECUTE FUNCTION protect_record_fields('status', 'updated_at');
CREATE TRIGGER calculator_configs_protect_version BEFORE UPDATE ON calculator_configs FOR EACH ROW
    EXECUTE FUNCTION protect_record_fields('status', 'created_by_id', 'updated_at');
CREATE TRIGGER ai_queries_protect_question BEFORE UPDATE ON ai_queries FOR EACH ROW
    EXECUTE FUNCTION protect_record_fields('status', 'updated_at');
CREATE TRIGGER scan_predictions_immutable BEFORE UPDATE ON scan_predictions FOR EACH ROW EXECUTE FUNCTION protect_record_fields();
CREATE TRIGGER model_metrics_immutable BEFORE UPDATE ON model_metrics FOR EACH ROW EXECUTE FUNCTION protect_record_fields();
CREATE TRIGGER ai_responses_immutable BEFORE UPDATE ON ai_responses FOR EACH ROW EXECUTE FUNCTION protect_record_fields();
CREATE TRIGGER history_immutable BEFORE UPDATE ON history FOR EACH ROW EXECUTE FUNCTION protect_record_fields();
CREATE FUNCTION protect_audit_record() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
    IF (to_jsonb(NEW) - 'actor_id') IS DISTINCT FROM (to_jsonb(OLD) - 'actor_id')
       OR (NEW.actor_id IS DISTINCT FROM OLD.actor_id AND NEW.actor_id IS NOT NULL) THEN
        RAISE EXCEPTION 'Audit records cannot be modified' USING ERRCODE = '23514';
    END IF;
    RETURN NEW;
END $$;
CREATE TRIGGER audit_logs_immutable BEFORE UPDATE ON audit_logs FOR EACH ROW EXECUTE FUNCTION protect_audit_record();

CREATE FUNCTION touch_updated_at() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN NEW.updated_at := clock_timestamp(); RETURN NEW; END $$;
DO $$
DECLARE table_name text;
BEGIN
    FOREACH table_name IN ARRAY ARRAY['users', 'farmer_profiles', 'diseases', 'disease_images',
        'disease_sources', 'scans', 'knowledge_documents', 'knowledge_chunks', 'fertilizers',
        'fertilizer_rules', 'calculator_configs', 'model_versions', 'ai_queries', 'notifications'] LOOP
        EXECUTE format('CREATE TRIGGER touch_updated_at BEFORE UPDATE ON %I FOR EACH ROW EXECUTE FUNCTION touch_updated_at()', table_name);
    END LOOP;
END $$;

-- Lock owner rows against concurrent role changes; invalid UUIDs remain FK errors.
CREATE FUNCTION enforce_farmer_owner() RETURNS trigger LANGUAGE plpgsql SET search_path FROM CURRENT AS $$
DECLARE owner_role text;
BEGIN
    IF NEW.user_id IS NOT NULL THEN
        SELECT role::text INTO owner_role FROM users WHERE id = NEW.user_id FOR SHARE;
        IF FOUND AND owner_role <> 'FARMER' THEN
            RAISE EXCEPTION 'This record must belong to a farmer' USING ERRCODE = '23514';
        END IF;
    END IF;
    RETURN NEW;
END $$;
CREATE TRIGGER farmer_profiles_farmer_owner BEFORE INSERT OR UPDATE ON farmer_profiles FOR EACH ROW EXECUTE FUNCTION enforce_farmer_owner();
CREATE TRIGGER scans_farmer_owner BEFORE INSERT OR UPDATE ON scans FOR EACH ROW EXECUTE FUNCTION enforce_farmer_owner();
CREATE TRIGGER history_farmer_owner BEFORE INSERT OR UPDATE ON history FOR EACH ROW EXECUTE FUNCTION enforce_farmer_owner();
CREATE FUNCTION protect_farmer_role() RETURNS trigger LANGUAGE plpgsql SET search_path FROM CURRENT AS $$
BEGIN
    IF NEW.role <> OLD.role AND (EXISTS (SELECT 1 FROM farmer_profiles WHERE user_id = OLD.id)
        OR EXISTS (SELECT 1 FROM scans WHERE user_id = OLD.id) OR EXISTS (SELECT 1 FROM history WHERE user_id = OLD.id)) THEN
        RAISE EXCEPTION 'Farmer role is referenced by existing records' USING ERRCODE = '23514';
    END IF;
    RETURN NEW;
END $$;
CREATE TRIGGER users_protect_farmer_role BEFORE UPDATE OF role ON users FOR EACH ROW EXECUTE FUNCTION protect_farmer_role();

CREATE FUNCTION validate_prediction_model() RETURNS trigger LANGUAGE plpgsql SET search_path FROM CURRENT AS $$
DECLARE labels text[];
BEGIN
    SELECT class_labels INTO labels FROM model_versions WHERE id = NEW.model_version_id;
    IF FOUND THEN
        IF NOT valid_probabilities(NEW.probabilities) THEN
            RAISE EXCEPTION 'Invalid probability distribution' USING ERRCODE = '23514';
        END IF;
        IF NOT (NEW.predicted_class = ANY(labels))
           OR ARRAY(SELECT jsonb_object_keys(NEW.probabilities) ORDER BY 1)
              IS DISTINCT FROM ARRAY(SELECT unnest(labels) ORDER BY 1)
           OR abs(NEW.confidence - (NEW.probabilities ->> NEW.predicted_class)::double precision) > 0.000001 THEN
            RAISE EXCEPTION 'Prediction must match the model class mapping and confidence' USING ERRCODE = '23514';
        END IF;
    END IF;
    RETURN NEW;
END $$;
CREATE TRIGGER scan_predictions_model_mapping BEFORE INSERT ON scan_predictions FOR EACH ROW EXECUTE FUNCTION validate_prediction_model();

CREATE FUNCTION validate_query_owner() RETURNS trigger LANGUAGE plpgsql SET search_path FROM CURRENT AS $$
DECLARE scan_owner uuid;
BEGIN
    IF NEW.scan_id IS NOT NULL THEN
        SELECT user_id INTO scan_owner FROM scans WHERE id = NEW.scan_id;
        IF FOUND AND scan_owner IS DISTINCT FROM NEW.user_id THEN
            RAISE EXCEPTION 'AI query and scan owners must match, including anonymous ownership' USING ERRCODE = '23514';
        END IF;
    END IF;
    RETURN NEW;
END $$;
CREATE TRIGGER ai_queries_scan_owner BEFORE INSERT ON ai_queries FOR EACH ROW EXECUTE FUNCTION validate_query_owner();
CREATE FUNCTION validate_history_calculator() RETURNS trigger LANGUAGE plpgsql SET search_path FROM CURRENT AS $$
DECLARE config_kind text;
BEGIN
    IF NEW.calculator_config_id IS NOT NULL THEN
        SELECT kind::text INTO config_kind FROM calculator_configs WHERE id = NEW.calculator_config_id;
        IF FOUND AND NEW.kind::text <> config_kind || '_CALCULATION' THEN
            RAISE EXCEPTION 'History must reference the matching calculator kind' USING ERRCODE = '23514';
        END IF;
    END IF;
    RETURN NEW;
END $$;
CREATE TRIGGER history_calculator_kind BEFORE INSERT ON history FOR EACH ROW EXECUTE FUNCTION validate_history_calculator();

COMMIT;
