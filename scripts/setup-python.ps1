param(
    [ValidateSet('ai-service', 'ml-training', 'All')]
    [string]$Component = 'All',
    [string]$Python = 'python'
)

$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path -Parent $PSScriptRoot
$env:UV_CACHE_DIR = Join-Path $repositoryRoot '.cache/uv'
$env:UV_PYTHON_DOWNLOADS = 'never'
$uvCommand = Get-Command uv -ErrorAction SilentlyContinue
$uv = if ($uvCommand) { $uvCommand.Source } else { Join-Path $repositoryRoot '.cache/tools/Scripts/uv.exe' }
if (-not (Test-Path -LiteralPath $uv)) {
    throw 'Install uv 0.12.23 first; see docs/15-development-environment.md.'
}
$pythonExecutable = & $Python -c 'import sys; assert sys.version_info[:2] == (3, 11); print(sys.executable)'
if ($LASTEXITCODE -ne 0) { throw 'Select a Python 3.11 executable using -Python.' }
$components = if ($Component -eq 'All') { @('ai-service', 'ml-training') } else { @($Component) }
foreach ($target in $components) {
    & $uv sync --locked --project (Join-Path $repositoryRoot $target) --python $pythonExecutable
    if ($LASTEXITCODE -ne 0) { throw "Dependency setup failed: $target" }
}
