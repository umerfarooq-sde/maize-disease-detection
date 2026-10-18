# Local reference-stack operations. Production rollout uses the protected release tool.
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('Prepare', 'Preflight', 'Config', 'Build', 'Start', 'Stop', 'Status', 'Database', 'Migrate', 'Model', 'E2E', 'Cleanup', 'Backup', 'Restore', 'Monitoring')]
    [string]$Action,
    [string]$EnvironmentFile,
    [string]$PythonExecutable,
    [string]$SecretsFile,
    [string]$ArtifactsDirectory,
    [string]$BackupDirectory,
    [string]$BackupFile,
    [string]$BackupKeyFile,
    [switch]$ShowPlan
)

$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path -Parent $PSScriptRoot
$runtimeDirectory = Join-Path $repositoryRoot 'infrastructure/runtime'
if (-not $PythonExecutable) { $PythonExecutable = Join-Path $repositoryRoot 'ai-service/.venv/Scripts/python.exe' }
if (-not $EnvironmentFile) { $EnvironmentFile = Join-Path $runtimeDirectory '.env.local' }
if (-not $ArtifactsDirectory) { $ArtifactsDirectory = Join-Path $runtimeDirectory 'artifacts' }
if (-not $BackupDirectory) { $BackupDirectory = Join-Path $runtimeDirectory 'backups' }
$steps = [System.Collections.Generic.List[object]]::new()
$compose = @('compose', '--env-file', $EnvironmentFile, '-f', (Join-Path $runtimeDirectory 'compose.yaml'), '-f', (Join-Path $runtimeDirectory 'compose.local.yaml'))
$operator = Join-Path $repositoryRoot 'infrastructure/operations/manage.py'

function Add-Step([string]$Executable, [string[]]$Arguments, [string]$InputText) {
    $steps.Add([PSCustomObject]@{ executable = $Executable; arguments = @($Arguments); inputText = $InputText })
}
function Require-Argument([string]$Name, [string]$Value) {
    if ([string]::IsNullOrWhiteSpace($Value)) { throw "-$Name is required for $Action. Supply a private file path, never credentials on the command line." }
}

switch ($Action) {
    'Prepare' { Add-Step $PythonExecutable @($operator, 'prepare-local') }
    'Preflight' { Add-Step $PythonExecutable @($operator, 'preflight', '--local', '--environment-file', $EnvironmentFile) }
    'Config' { Add-Step 'docker' ($compose + @('config', '--quiet')) }
    'Build' { Add-Step 'docker' ($compose + @('build', 'api', 'migrate', 'ai', 'backups')) }
    'Start' { Add-Step 'docker' ($compose + @('up', '-d', '--build', '--wait', '--wait-timeout', '1200')) }
    'Stop' { Add-Step 'docker' ($compose + @('stop')) }
    'Status' { Add-Step 'docker' ($compose + @('ps')) }
    'Database' {
        Add-Step 'docker' ($compose + @('run', '--rm', '--no-deps', 'migrate', 'migrate', 'status'))
        Add-Step 'docker' ($compose + @('exec', '-T', 'api', 'node', 'dist/cli/readiness.js'))
    }
    'Migrate' { Add-Step 'docker' ($compose + @('run', '--rm', '--no-deps', 'migrate', 'migrate', 'deploy')) }
    'Model' { Add-Step $PythonExecutable @($operator, 'verify-model', '--artifacts', $ArtifactsDirectory) }
    'E2E' { Add-Step $PythonExecutable @((Join-Path $repositoryRoot 'scripts/check-e2e.py')) }
    'Cleanup' {
        # Start/reconcile the existing lease-coordinated scheduled worker. Never
        # bypass its asset journals or create a second ad-hoc deletion path.
        Add-Step 'docker' ($compose + @('up', '-d', '--no-deps', 'cleanup'))
    }
    'Backup' {
        Require-Argument 'SecretsFile' $SecretsFile
        Require-Argument 'BackupKeyFile' $BackupKeyFile
        Add-Step $PythonExecutable @($operator, 'backup', '--secrets', $SecretsFile, '--output', $BackupDirectory, '--key', $BackupKeyFile, '--artifacts', $ArtifactsDirectory)
    }
    'Restore' {
        Require-Argument 'SecretsFile' $SecretsFile
        Require-Argument 'BackupKeyFile' $BackupKeyFile
        Require-Argument 'BackupFile' $BackupFile
        # The existing tool authenticates, creates a NEW owned restore database,
        # verifies it and removes that target. It never restores over the source.
        Add-Step $PythonExecutable @($operator, 'restore-drill', '--secrets', $SecretsFile, '--backup', $BackupFile, '--key', $BackupKeyFile)
    }
    'Monitoring' {
        Add-Step 'docker' ($compose + @('exec', '-T', 'api', 'node', 'dist/cli/readiness.js'))
        Add-Step 'docker' ($compose + @('exec', '-T', 'ai', '/app/ai-service/.venv/bin/python', '-m', 'app.healthcheck'))
        # No invented health: require an actual successful scrape for every
        # configured class of service. Host observer/paging are separate gates.
        $probe = 'const r=await fetch("http://prometheus:9090/api/v1/targets",{signal:AbortSignal.timeout(5000)});if(!r.ok)throw Error("Prometheus unavailable");const t=(await r.json()).data.activeTargets;for(const j of ["node","ai","cleanup","backups","alerts"]){const a=t.filter(x=>x.labels.job===j);if(!a.length||a.some(x=>x.health!=="up"))throw Error("Private scrape unavailable: "+j)}console.log("PASS: all configured private service scrapes; not public-release approval")'
        Add-Step 'docker' ($compose + @('exec', '-T', 'api', 'node', '--input-type=module', '-')) $probe
    }
}

if ($ShowPlan) {
    [PSCustomObject]@{ action = $Action; willExecute = $false; steps = @($steps.ToArray()) } | ConvertTo-Json -Depth 5
    return
}

if (@($steps | Where-Object { $_.executable -eq 'docker' }).Count -gt 0) {
    if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
        throw 'Docker CLI/Engine is unavailable. Install an authorized Docker host first; no services were started or data changed. -ShowPlan performs no execution.'
    }
    & docker info --format '{{.ServerVersion}}' 2>$null | Out-Null
    if ($LASTEXITCODE -ne 0) { throw 'Docker Engine is unreachable. No stack commands were executed.' }
}
if (@($steps | Where-Object { $_.executable -eq $PythonExecutable }).Count -gt 0 -and -not (Test-Path -LiteralPath $PythonExecutable -PathType Leaf)) {
    throw 'Project Python is unavailable. Run scripts/setup-python.ps1 before operations.'
}

Push-Location $repositoryRoot
try {
    foreach ($step in $steps) {
        $executable = $step.executable
        $commandArguments = $step.arguments
        if ($step.inputText) { $step.inputText | & $executable @commandArguments }
        else { & $executable @commandArguments }
        if ($LASTEXITCODE -ne 0) { throw "Operation $Action failed (exit $LASTEXITCODE). Stop and inspect safe diagnostics; no automatic destructive retry." }
    }
} finally { Pop-Location }
