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
$architectureDocs = @(
    '01-system-overview.md', '02-hla.md', '03-hld.md', '04-lld.md',
    '05-database-design.md', '06-api-design.md', '07-flutter-architecture.md',
    '08-ai-architecture.md', '09-ml-pipeline.md', '10-rag-architecture.md',
    '11-security.md', '12-testing.md', '13-deployment.md'
)
$requiredFiles += @(
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
    'backend' = @('NODE_ENV', 'PORT', 'HOST', 'CORS_ORIGINS', 'LOG_LEVEL', 'SHUTDOWN_TIMEOUT_MS', 'RATE_LIMIT_MAX', 'DATABASE_URL', 'DIRECT_DATABASE_URL', 'JWT_SECRET', 'JWT_REFRESH_SECRET', 'CLOUDINARY_CLOUD_NAME', 'CLOUDINARY_API_KEY', 'CLOUDINARY_API_SECRET', 'AI_SERVICE_URL', 'AI_SERVICE_TOKEN')
    'ai-service' = @('ENVIRONMENT', 'PORT', 'DATABASE_URL', 'GEMINI_API_KEY', 'AI_SERVICE_TOKEN', 'MODEL_PATH', 'MODEL_VERSION', 'PREPROCESSING_VERSION')
    'infrastructure' = @('POSTGRES_DB', 'POSTGRES_USER', 'POSTGRES_PASSWORD', 'POSTGRES_PORT')
    'mobile' = @('API_BASE_URL')
}
$blankKeys = @('DATABASE_URL', 'DIRECT_DATABASE_URL', 'JWT_SECRET', 'JWT_REFRESH_SECRET', 'CLOUDINARY_CLOUD_NAME', 'CLOUDINARY_API_KEY', 'CLOUDINARY_API_SECRET', 'GEMINI_API_KEY', 'AI_SERVICE_TOKEN', 'POSTGRES_USER', 'POSTGRES_PASSWORD')
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
    'infrastructure/.env', 'mobile/.env', 'backend/node_modules/probe.js',
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
