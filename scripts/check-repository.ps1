# Read-only repository foundation checks. No provider connections are required.
$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path -Parent $PSScriptRoot
$requiredDirectories = @('mobile', 'backend', 'ai-service', 'ml-training', 'docs', 'scripts', 'infrastructure')
$requiredFiles = @('AGENTS.md', 'README.md', '.gitignore', 'docs/README.md', 'docs/PROJECT_STATE.md', 'docs/DECISIONS.md', 'docs/14-roadmap.md')
$requiredFiles += @(
    'docs/15-development-environment.md', 'backend/package.json', 'backend/package-lock.json',
    'backend/tsconfig.json', 'backend/.node-version', 'backend/src/environment-check.ts',
    'backend/src/database-check.ts', 'ai-service/pyproject.toml', 'ai-service/uv.lock',
    'ai-service/.python-version', 'ai-service/tests/test_environment.py',
    'ml-training/pyproject.toml', 'ml-training/uv.lock', 'ml-training/.python-version',
    'ml-training/tests/test_environment.py', 'mobile/pubspec.yaml', 'mobile/pubspec.lock',
    'mobile/.flutter-version', 'mobile/analysis_options.yaml', 'mobile/lib/main.dart',
    'mobile/test/environment_test.dart', 'mobile/android/app/build.gradle.kts',
    'infrastructure/compose.yaml', 'scripts/initialize-dev-env.ps1', 'scripts/postgres-local.ps1',
    'scripts/setup-python.ps1', 'scripts/check-development.ps1', 'scripts/requirements-tools.txt'
)
$requiredFiles += @(
    'backend/prisma.config.ts', 'backend/tsconfig.database.json', 'backend/prisma/schema.prisma',
    'backend/prisma/migrations/migration_lock.toml',
    'backend/prisma/migrations/20261005000000_initial_schema/migration.sql',
    'backend/prisma/migrations/20261005010000_enforce_immutable_records/migration.sql',
    'backend/prisma/migrations/20261005020000_protect_version_creator/migration.sql',
    'backend/prisma/seed.ts', 'backend/prisma/seed-data.ts', 'backend/src/database/client.ts',
    'backend/tests/database-support.ts', 'backend/tests/database.integration.test.ts',
    'backend/tests/migration-replay.ts', 'docs/16-database-operations.md'
)
$requiredFiles += @(
    'docs/20-scan-uploads.md', 'scripts/check-scan-upload.mjs',
    'backend/prisma/migrations/20261006010000_scan_uploads/migration.sql',
    'backend/src/modules/scans/scan.routes.ts', 'backend/src/modules/scans/scan.controller.ts',
    'backend/src/modules/scans/scan.service.ts', 'backend/src/modules/scans/scan.repository.ts',
    'backend/src/modules/scans/scan.storage.ts', 'backend/src/modules/scans/scan.validation.ts',
    'backend/src/modules/scans/scan.types.ts', 'backend/src/cli/cleanup-scan-uploads.ts',
    'backend/tests/scans/upload.test.ts', 'backend/tests/scans/http.test.ts',
    'backend/tests/scans.database.integration.ts', 'backend/tests/scans.live.integration.ts',
    'mobile/lib/core/network/upload_request.dart',
    'mobile/lib/data/datasources/leaf_image_datasource.dart',
    'mobile/lib/data/datasources/scan_datasource.dart', 'mobile/lib/data/models/scan_record.dart',
    'mobile/lib/data/models/selected_leaf_image.dart', 'mobile/lib/data/repositories/scan_repository.dart',
    'mobile/lib/features/disease_detection/view_models/scan_view_model.dart',
    'mobile/lib/features/disease_detection/widgets/scan_preview.dart',
    'mobile/test/scans/selection_test.dart', 'mobile/test/scans/transport_test.dart',
    'mobile/test/scans/view_model_test.dart', 'mobile/test/scans/widget_test.dart',
    'mobile/test/integration/scan_upload_test.dart'
)
$architectureDocs = @(
    '01-system-overview.md', '02-hla.md', '03-hld.md', '04-lld.md',
    '05-database-design.md', '06-api-design.md', '07-flutter-architecture.md',
    '08-ai-architecture.md', '09-ml-pipeline.md', '10-rag-architecture.md',
    '11-security.md', '12-testing.md', '13-deployment.md'
)
$requiredFiles += @(
    'docs/28-node-fastapi-integration.md',
    'backend/prisma/migrations/20261009000000_scan_inference/migration.sql',
    'backend/src/modules/inference/inference.client.ts',
    'backend/src/modules/inference/inference.types.ts',
    'backend/src/modules/inference/model-registration.ts',
    'backend/src/modules/inference/model.repository.ts', 'backend/src/cli/register-model.ts',
    'backend/src/modules/scans/image-admission.ts', 'backend/tests/inference/client.test.ts',
    'backend/tests/inference/model-registration.test.ts', 'backend/tests/inference/logger.test.ts',
    'backend/tests/scans/inference.test.ts', 'backend/tests/scans/read-http.test.ts',
    'backend/tests/scans/admission.test.ts', 'backend/tests/scans.inference.integration.ts',
    'backend/tests/scans.inference.live.integration.ts', 'mobile/lib/data/models/scan_prediction.dart',
    'scripts/check-image-admission-contract.py', 'scripts/check-image-admission-contract.mjs'
)
$requiredFiles += @(
    'docs/21-ai-service-foundation.md', 'scripts/start-ai.ps1',
    'ai-service/app/main.py', 'ai-service/app/server.py',
    'ai-service/app/config/settings.py', 'ai-service/app/api/security.py',
    'ai-service/app/api/middleware.py', 'ai-service/app/api/routes/health.py',
    'ai-service/app/schemas/common.py', 'ai-service/app/schemas/health.py',
    'ai-service/app/schemas/errors.py', 'ai-service/app/utils/logging.py',
    'ai-service/app/utils/errors.py', 'ai-service/app/preprocessing/README.md',
    'ai-service/app/inference/README.md', 'ai-service/app/rag/README.md',
    'ai-service/app/model_management/README.md'
)
$requiredFiles += @(
    'docs/27-production-ml-inference.md', 'scripts/check-inference-parity.py',
    'ai-service/app/api/routes/prediction.py', 'ai-service/app/inference/service.py',
    'ai-service/app/model_management/artifacts.py', 'ai-service/app/model_management/confidence.py',
    'ai-service/app/schemas/prediction.py', 'ai-service/app/schemas/model_health.py',
    'ai-service/tests/model_fixtures.py', 'ai-service/tests/test_model_artifacts.py',
    'ai-service/tests/test_confidence_policy.py', 'ai-service/tests/test_inference.py',
    'ai-service/tests/test_prediction_api.py'
)
$requiredFiles += @(
    'backend/prisma/migrations/20261006000000_auth_sessions/migration.sql',
    'backend/src/middleware/authentication.ts', 'backend/src/middleware/authorization.ts',
    'backend/src/modules/auth/auth.types.ts', 'backend/src/modules/auth/auth.repository.ts',
    'backend/src/modules/auth/auth.service.ts', 'backend/src/modules/auth/auth.controller.ts',
    'backend/src/modules/auth/auth.routes.ts', 'backend/src/modules/auth/auth.validators.ts',
    'backend/src/modules/auth/auth.tokens.ts', 'backend/src/modules/auth/auth.password.ts',
    'backend/src/modules/auth/auth.cookies.ts', 'backend/src/cli/create-admin.ts',
    'backend/tests/auth/helpers.ts', 'backend/tests/auth/http.test.ts',
    'backend/tests/auth/service.test.ts', 'backend/tests/auth.database.integration.ts',
    'scripts/initialize-auth-env.ps1', 'scripts/create-admin.ps1', 'docs/18-authentication.md'
)
$requiredFiles += @(
    'shared/preprocessing/README.md', 'shared/preprocessing/pyproject.toml',
    'shared/preprocessing/configs/default.json', 'docs/22-shared-preprocessing.md',
    'shared/preprocessing/src/maizedoctor_preprocessing/__init__.py',
    'shared/preprocessing/src/maizedoctor_preprocessing/config.py',
    'shared/preprocessing/src/maizedoctor_preprocessing/decoding.py',
    'shared/preprocessing/src/maizedoctor_preprocessing/segmentation.py',
    'shared/preprocessing/src/maizedoctor_preprocessing/pipeline.py',
    'shared/preprocessing/src/maizedoctor_preprocessing/debug.py',
    'shared/preprocessing/tests/test_contract.py',
    'shared/preprocessing/tests/test_decoding.py',
    'shared/preprocessing/tests/test_segmentation.py',
    'shared/preprocessing/tests/test_debug.py',
    'ai-service/app/preprocessing/__init__.py', 'ml-training/preprocessing.py',
    'ai-service/tests/test_preprocessing.py', 'ml-training/tests/test_preprocessing.py',
    'scripts/check-preprocessing-parity.py'
)
$requiredFiles += @(
    'ml-training/.env.example', 'ml-training/configuration.py',
    'ml-training/dataset_inventory.py', 'ml-training/dataset_review.py',
    'ml-training/tests/test_configuration.py', 'ml-training/tests/test_dataset_review.py',
    'ml-training/dataset_preparation.py', 'ml-training/training_data.py',
    'ml-training/model.py', 'ml-training/train.py', 'ml-training/evaluation.py',
    'ml-training/configs/full-frame-baseline.json', 'ml-training/configs/research-policy.json',
    'ml-training/configs/group-evidence.json', 'ml-training/tests/test_dataset_preparation.py',
    'ml-training/tests/test_evaluation.py', 'ml-training/tests/test_training.py',
    'docs/25-ml-training-evaluation.md',
    'backend/biome.json', 'backend/src/app.ts', 'backend/src/application.ts',
    'backend/src/server.ts', 'backend/src/config/environment.ts', 'backend/src/config/logger.ts',
    'backend/src/database/connection-url.ts', 'backend/src/errors/app-error.ts',
    'backend/src/middleware/error-handler.ts', 'backend/src/middleware/request-context.ts',
    'backend/src/middleware/rate-limit.ts', 'backend/src/validators/request.ts',
    'backend/src/routes/index.ts', 'backend/src/modules/health/health.routes.ts',
    'backend/src/modules/health/health.controller.ts', 'backend/src/modules/health/health.service.ts',
    'backend/src/modules/health/health.repository.ts', 'backend/src/types/api.ts',
    'backend/src/types/express.d.ts', 'backend/src/utils/respond.ts',
    'backend/tests/foundation/helpers.ts', 'backend/tests/foundation/environment.test.ts',
    'backend/tests/foundation/http.test.ts', 'backend/tests/foundation/lifecycle.test.ts',
    'docs/17-backend-foundation.md'
)
$requiredFiles += @(
    'mobile/lib/app.dart', 'mobile/lib/core/theme/design_tokens.dart',
    'mobile/lib/core/theme/app_theme.dart', 'mobile/lib/core/routes/app_router.dart',
    'mobile/lib/core/network/api_client.dart', 'mobile/lib/core/network/app_config.dart',
    'mobile/lib/core/exceptions/app_exception.dart', 'mobile/lib/core/storage/access_token_source.dart',
    'mobile/lib/data/repositories/backend_repository.dart',
    'mobile/lib/features/home/view_models/home_view_model.dart',
    'mobile/lib/features/shell/views/farmer_shell.dart',
    'mobile/test/core/api_client_test.dart', 'mobile/test/features/home_view_model_test.dart',
    'mobile/test/widgets/foundation_test.dart', 'mobile/test/integration/backend_connection_test.dart',
    'docs/19-flutter-foundation.md'
)
foreach ($directory in $requiredDirectories) {
    if (-not (Test-Path -LiteralPath (Join-Path $repositoryRoot $directory) -PathType Container)) {
        throw "Missing directory: $directory"
    }
    $requiredFiles += "$directory/README.md"
}
foreach ($document in $architectureDocs) { $requiredFiles += "docs/$document" }
foreach ($component in @('mobile', 'backend', 'ai-service', 'infrastructure')) {
    $requiredFiles += "$component/.env.example"
}
foreach ($file in $requiredFiles) {
    $filePath = Join-Path $repositoryRoot $file
    if (-not (Test-Path -LiteralPath $filePath -PathType Leaf)) { throw "Missing file: $file" }
    if ((Get-Item -LiteralPath $filePath).Length -eq 0) { throw "Empty required file: $file" }
}
Write-Output 'PASS: Required directories, documentation, and templates exist.'

$templateKeys = @{
    'backend' = @('NODE_ENV', 'PORT', 'HOST', 'CORS_ORIGINS', 'LOG_LEVEL', 'SHUTDOWN_TIMEOUT_MS', 'RATE_LIMIT_MAX', 'AUTH_RATE_LIMIT_MAX', 'SCAN_RATE_LIMIT_MAX', 'DATABASE_URL', 'DIRECT_DATABASE_URL', 'JWT_SECRET', 'JWT_REFRESH_SECRET', 'JWT_ISSUER', 'JWT_ACCESS_TTL_SECONDS', 'JWT_REFRESH_TTL_SECONDS', 'CLOUDINARY_CLOUD_NAME', 'CLOUDINARY_API_KEY', 'CLOUDINARY_API_SECRET', 'AI_SERVICE_URL', 'AI_SERVICE_TOKEN', 'AI_SERVICE_TIMEOUT_MS', 'AI_MODEL_VERSION', 'AI_PREPROCESSING_VERSION')
    'ai-service' = @('ENVIRONMENT', 'HOST', 'PORT', 'LOG_LEVEL', 'DATABASE_URL', 'GEMINI_API_KEY', 'AI_SERVICE_TOKEN', 'INFERENCE_ENABLED', 'MODEL_PATH', 'MODEL_METADATA_PATH', 'MODEL_METADATA_SHA256', 'MODEL_VERSION', 'PREPROCESSING_VERSION', 'INFERENCE_THREADS', 'INFERENCE_MAX_CONCURRENCY', 'INFERENCE_UPLOAD_TIMEOUT_SECONDS', 'CONFIDENCE_POLICY_PATH', 'CONFIDENCE_POLICY_SHA256')
    'infrastructure' = @('POSTGRES_DB', 'POSTGRES_USER', 'POSTGRES_PASSWORD', 'POSTGRES_PORT')
    'mobile' = @('API_BASE_URL')
    'ml-training' = @('DATASET_PATH')
}
$blankKeys = @('DATABASE_URL', 'DIRECT_DATABASE_URL', 'JWT_SECRET', 'JWT_REFRESH_SECRET', 'CLOUDINARY_CLOUD_NAME', 'CLOUDINARY_API_KEY', 'CLOUDINARY_API_SECRET', 'GEMINI_API_KEY', 'AI_SERVICE_TOKEN', 'POSTGRES_USER', 'POSTGRES_PASSWORD', 'DATASET_PATH')
foreach ($component in $templateKeys.Keys) {
    $seenKeys = @{}
    foreach ($line in Get-Content -LiteralPath (Join-Path $repositoryRoot "$component/.env.example")) {
        if ($line -match '^\s*(#.*)?$') { continue }
        if ($line -notmatch '^([A-Z][A-Z0-9_]*)=(.*)$') { throw "Invalid environment template line in $component" }
        $key = $Matches[1]
        $value = $Matches[2]
        if ($seenKeys.ContainsKey($key)) { throw "Duplicate template key: $component/$key" }
        if ($key -notin $templateKeys[$component]) { throw "Unexpected template key: $component/$key" }
        if ($key -in $blankKeys -and $value.Length -ne 0) { throw "Credential placeholder must be blank: $component/$key" }
        $seenKeys[$key] = $true
    }
    foreach ($key in $templateKeys[$component]) {
        if (-not $seenKeys.ContainsKey($key)) { throw "Missing template key: $component/$key" }
    }
}
Write-Output 'PASS: Environment templates have expected keys and blank credentials; mobile has only public configuration.'

$gitRoot = & git -C $repositoryRoot rev-parse --show-toplevel
if ($LASTEXITCODE -ne 0) { throw 'Git repository is not initialized.' }
if ([IO.Path]::GetFullPath($gitRoot) -ne [IO.Path]::GetFullPath($repositoryRoot)) {
    throw 'Workspace must be its own Git repository.'
}
$ignoredPaths = @(
    '.env', '.env.production', 'backend/.env', 'ai-service/.env.local',
    'infrastructure/.env', 'mobile/.env', 'ml-training/.env', 'backend/node_modules/probe.js',
    'backend/dist/probe.js', 'ai-service/.venv/probe', 'ai-service/__pycache__/probe.pyc',
    'mobile/.dart_tool/probe', 'mobile/build/probe', 'mobile/android/local.properties',
    'mobile/android/key.properties', 'mobile/ios/Pods/probe', 'mobile/release.jks',
    'ml-training/datasets/raw/probe.jpg', 'ml-training/models/probe.pt',
    'infrastructure/data/probe', 'backend/uploads/probe.jpg', 'logs/probe.log',
    '.cache/tools/probe.exe', 'ml-training/.venv/probe', 'backend/src/generated/prisma/client.ts'
)
$ignoredResults = @(& git -C $repositoryRoot check-ignore --no-index -- $ignoredPaths)
if ($LASTEXITCODE -ne 0) { throw 'Git ignore check failed.' }
foreach ($path in $ignoredPaths) {
    if ($path -notin $ignoredResults) { throw "Local/generated file is not ignored: $path" }
}
$visiblePaths = $requiredFiles + @(
    'scripts/check-repository.ps1', 'backend/package-lock.json', 'mobile/pubspec.lock',
    'backend/prisma/migrations/example/migration.sql', 'backend/src/example.ts',
    'mobile/lib/example.dart', 'ai-service/example.py', 'ml-training/experiments/example.json'
)
$unexpectedIgnored = @(& git -C $repositoryRoot check-ignore --no-index -- $visiblePaths)
$ignoreExit = $LASTEXITCODE
if ($ignoreExit -gt 1) { throw 'Git source visibility check failed.' }
if ($unexpectedIgnored.Count -ne 0) { throw ('Required/source files are ignored: ' + ($unexpectedIgnored -join ', ')) }
Write-Output 'PASS: Git root and ignore rules protect local artifacts while keeping source, templates, migrations, and lockfiles visible.'
Write-Output 'Repository foundation checks passed.'
