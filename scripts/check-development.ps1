param(
    [ValidateSet('Backend', 'AI', 'Training', 'Preprocessing', 'Flutter', 'Database', 'Prisma', 'Docker', 'All')]
    [string]$Component = 'All'
)

$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path -Parent $PSScriptRoot
$components = if ($Component -eq 'All') { @('Backend', 'AI', 'Training', 'Preprocessing', 'Flutter', 'Database', 'Prisma', 'Docker') } else { @($Component) }
$failed = @()
foreach ($target in $components) {
    try {
        switch ($target) {
            'Backend' {
                Push-Location (Join-Path $repositoryRoot 'backend')
                try {
                    & npm.cmd run check
                    if ($LASTEXITCODE -ne 0) { throw 'Backend formatting/lint/type/build/test/dependency checks failed.' }
                } finally { Pop-Location }
            }
            { $_ -in @('AI', 'Training') } {
                $directory = if ($target -eq 'AI') { 'ai-service' } else { 'ml-training' }
                Push-Location (Join-Path $repositoryRoot $directory)
                try {
                    $python = Join-Path $PWD '.venv/Scripts/python.exe'
                    if (-not (Test-Path -LiteralPath $python)) { throw "Run setup-python.ps1 for $directory first." }
                    if ($target -eq 'AI') {
                        & $python -m ruff format --check app tests ../scripts/check-inference-parity.py
                        if ($LASTEXITCODE -ne 0) { throw 'AI formatting check failed.' }
                        & $python -m ruff check app tests ../scripts/check-inference-parity.py
                        if ($LASTEXITCODE -ne 0) { throw 'AI lint check failed.' }
                        & $python -m mypy
                        if ($LASTEXITCODE -ne 0) { throw 'AI strict type check failed.' }
                    } else {
                        & $python -m ruff format --check .
                        if ($LASTEXITCODE -ne 0) { throw 'Training formatting check failed.' }
                        & $python -m ruff check .
                        if ($LASTEXITCODE -ne 0) { throw 'Training lint check failed.' }
                        & $python -m mypy
                        if ($LASTEXITCODE -ne 0) { throw 'Training strict type check failed.' }
                    }
                    & $python -m pytest
                    if ($LASTEXITCODE -ne 0) { throw "$directory tests failed." }
                } finally { Pop-Location }
            }
            'Preprocessing' {
                Push-Location $repositoryRoot
                try {
                    $aiPython = Join-Path $repositoryRoot 'ai-service/.venv/Scripts/python.exe'
                    $trainingPython = Join-Path $repositoryRoot 'ml-training/.venv/Scripts/python.exe'
                    foreach ($python in @($aiPython, $trainingPython)) {
                        if (-not (Test-Path -LiteralPath $python)) { throw 'Set up both Python environments first.' }
                    }
                    & $aiPython -m ruff format --check shared/preprocessing scripts/check-preprocessing-parity.py
                    if ($LASTEXITCODE -ne 0) { throw 'Shared preprocessing formatting failed.' }
                    & $aiPython -m ruff check shared/preprocessing scripts/check-preprocessing-parity.py
                    if ($LASTEXITCODE -ne 0) { throw 'Shared preprocessing lint failed.' }
                    & $aiPython -m mypy --config-file shared/preprocessing/pyproject.toml shared/preprocessing/src
                    if ($LASTEXITCODE -ne 0) { throw 'Shared preprocessing strict type check failed.' }
                    foreach ($python in @($aiPython, $trainingPython)) {
                        & $python -m pytest shared/preprocessing/tests
                        if ($LASTEXITCODE -ne 0) { throw 'Shared preprocessing tests failed.' }
                    }
                    & $aiPython scripts/check-preprocessing-parity.py --config ml-training/configs/full-frame-baseline.json
                    if ($LASTEXITCODE -ne 0) { throw 'Training/serving preprocessing parity failed.' }
                } finally { Pop-Location }
            }
            'Flutter' {
                Push-Location (Join-Path $repositoryRoot 'mobile')
                try {
                    & flutter analyze
                    if ($LASTEXITCODE -ne 0) { throw 'Flutter analyzer failed.' }
                    & flutter test
                    if ($LASTEXITCODE -ne 0) { throw 'Flutter environment test failed.' }
                } finally { Pop-Location }
            }
            'Database' {
                Push-Location (Join-Path $repositoryRoot 'backend')
                try {
                    & npm.cmd run check:database
                    if ($LASTEXITCODE -ne 0) { throw 'PostgreSQL connection/SQL check failed.' }
                } finally { Pop-Location }
            }
            'Prisma' {
                Push-Location (Join-Path $repositoryRoot 'backend')
                try {
                    & npm.cmd run db:check
                    if ($LASTEXITCODE -ne 0) { throw 'Prisma/database integration checks failed.' }
                    & npm.cmd run db:status
                    if ($LASTEXITCODE -ne 0) { throw 'Prisma migration history check failed.' }
                } finally { Pop-Location }
            }
            'Docker' {
                $composeArgs = @('--env-file', (Join-Path $repositoryRoot 'infrastructure/.env'), '-f', (Join-Path $repositoryRoot 'infrastructure/compose.yaml'), 'config', '--quiet')
                if (Get-Command docker -ErrorAction SilentlyContinue) {
                    & docker compose @composeArgs
                } elseif (Test-Path -LiteralPath (Join-Path $repositoryRoot '.cache/tools/docker-compose.exe')) {
                    & (Join-Path $repositoryRoot '.cache/tools/docker-compose.exe') @composeArgs
                } else { throw 'Docker/Compose is missing; see the development setup guide.' }
                if ($LASTEXITCODE -ne 0) { throw 'Compose configuration validation failed.' }
                Write-Output 'PASS: Compose configuration validation (does not require or verify a container runtime).'
            }
        }
        Write-Output "PASS: $target"
    } catch {
        $failed += $target
        Write-Output "FAIL: $target - $($_.Exception.Message)"
    }
}
if ($failed.Count -gt 0) { throw ('Development checks failed: ' + ($failed -join ', ')) }
