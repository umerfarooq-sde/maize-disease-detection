# Run the internal FastAPI foundation with validated server-only settings.
$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path -Parent $PSScriptRoot
$serviceRoot = Join-Path $repositoryRoot 'ai-service'
$python = Join-Path $serviceRoot '.venv/Scripts/python.exe'
if (-not (Test-Path -LiteralPath $python)) {
    throw 'Run scripts/setup-python.ps1 -Component ai-service first.'
}
Push-Location $serviceRoot
try {
    & $python -m app.server
    if ($LASTEXITCODE -ne 0) { throw 'AI service exited unsuccessfully; inspect its safe JSON events.' }
} finally {
    Pop-Location
}
