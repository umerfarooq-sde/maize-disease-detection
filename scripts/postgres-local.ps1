param(
    [ValidateSet('Start', 'Stop', 'Check')]
    [string]$Action = 'Check',
    [string]$PostgresBin = $env:MAIZEDOCTOR_PG_BIN
)

$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path -Parent $PSScriptRoot
if (-not $PostgresBin) { $PostgresBin = 'C:\Program Files\PostgreSQL\18\bin' }
foreach ($tool in @('pg_ctl', 'initdb', 'psql', 'createdb')) {
    if (-not (Test-Path -LiteralPath (Join-Path $PostgresBin "$tool.exe"))) {
        throw "PostgreSQL tools missing. Supply -PostgresBin or use Docker Compose."
    }
}
$settings = @{}
$envPath = Join-Path $repositoryRoot 'infrastructure/.env'
if (-not (Test-Path -LiteralPath $envPath)) { throw 'Run initialize-dev-env.ps1 first.' }
foreach ($line in Get-Content -LiteralPath $envPath) {
    if ($line -match '^([A-Z_]+)=(.*)$') { $settings[$Matches[1]] = $Matches[2] }
}
foreach ($key in @('POSTGRES_USER', 'POSTGRES_DB')) {
    if ($settings[$key] -notmatch '^[a-z][a-z0-9_]{0,62}$') { throw "Unsupported local identifier: $key" }
}
if (-not $settings['POSTGRES_PASSWORD']) { throw 'A local PostgreSQL password is required.' }
$port = 0
if (-not [int]::TryParse($settings['POSTGRES_PORT'], [ref]$port) -or $port -lt 1024 -or $port -gt 65535) {
    throw 'POSTGRES_PORT must be an unprivileged TCP port.'
}
$dataRoot = Join-Path $repositoryRoot 'infrastructure/data'
$cluster = Join-Path $dataRoot 'postgres'
$pgCtl = Join-Path $PostgresBin 'pg_ctl.exe'
if ($Action -eq 'Stop') {
    if (Test-Path -LiteralPath (Join-Path $cluster 'postmaster.pid')) {
        & $pgCtl -D $cluster -m fast -w stop
        if ($LASTEXITCODE -ne 0) { throw 'Local PostgreSQL stop failed.' }
    }
    exit 0
}
if ($Action -eq 'Start') {
    if (-not (Test-Path -LiteralPath (Join-Path $cluster 'PG_VERSION'))) {
        # Do not initialize on an occupied port or reuse an unrelated existing service.
        $listener = New-Object Net.Sockets.TcpClient
        try {
            try { $listener.Connect('127.0.0.1', $port) } catch { }
            if ($listener.Connected) { throw "Port $port is occupied; select another POSTGRES_PORT." }
        } finally { $listener.Dispose() }
        New-Item -ItemType Directory -Force -Path $dataRoot | Out-Null
        $passwordFile = Join-Path $dataRoot 'init-password.tmp'
        try {
            [IO.File]::WriteAllText($passwordFile, $settings['POSTGRES_PASSWORD'], (New-Object Text.UTF8Encoding($false)))
            & (Join-Path $PostgresBin 'initdb.exe') -D $cluster -U $settings['POSTGRES_USER'] --pwfile=$passwordFile --auth=scram-sha-256 --encoding=UTF8 --locale=C
            if ($LASTEXITCODE -ne 0) { throw 'Local PostgreSQL initialization failed.' }
        } finally {
            if (Test-Path -LiteralPath $passwordFile) { Remove-Item -LiteralPath $passwordFile }
        }
    }
    if (-not (Test-Path -LiteralPath (Join-Path $cluster 'postmaster.pid'))) {
        & $pgCtl -D $cluster -l (Join-Path $dataRoot 'postgres.log') -o "-h 127.0.0.1 -p $port" -w start
        if ($LASTEXITCODE -ne 0) { throw 'Local PostgreSQL start failed; inspect infrastructure/data/postgres.log.' }
    }
}
$priorPassword = $env:PGPASSWORD
$env:PGPASSWORD = $settings['POSTGRES_PASSWORD']
try {
    $connectionArgs = @('-h', '127.0.0.1', '-p', "$port", '-U', $settings['POSTGRES_USER'], '-w')
    if ($Action -eq 'Start') {
        $exists = & (Join-Path $PostgresBin 'psql.exe') @connectionArgs -d postgres -Atqc "SELECT 1 FROM pg_database WHERE datname = '$($settings['POSTGRES_DB'])'"
        if ($LASTEXITCODE -ne 0) { throw 'Local database connection failed.' }
        if ($exists -ne '1') {
            & (Join-Path $PostgresBin 'createdb.exe') @connectionArgs $settings['POSTGRES_DB']
            if ($LASTEXITCODE -ne 0) { throw 'Local development database creation failed.' }
        }
    }
    & (Join-Path $PostgresBin 'psql.exe') @connectionArgs -d $settings['POSTGRES_DB'] -v ON_ERROR_STOP=1 -c 'SELECT current_database(), current_user, version();'
    if ($LASTEXITCODE -ne 0) { throw 'PostgreSQL connection check failed.' }
} finally { $env:PGPASSWORD = $priorPassword }
