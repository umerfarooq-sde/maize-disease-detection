# Creates ignored local development settings without printing credentials.
$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path -Parent $PSScriptRoot
$utf8 = New-Object System.Text.UTF8Encoding($false)
$infrastructureEnv = Join-Path $repositoryRoot 'infrastructure/.env'
if (-not (Test-Path -LiteralPath $infrastructureEnv)) {
    $randomBytes = New-Object byte[] 32
    $generator = [Security.Cryptography.RandomNumberGenerator]::Create()
    try { $generator.GetBytes($randomBytes) } finally { $generator.Dispose() }
    $password = ([BitConverter]::ToString($randomBytes)).Replace('-', '').ToLowerInvariant()
    $template = [IO.File]::ReadAllText((Join-Path $repositoryRoot 'infrastructure/.env.example'))
    $template = $template.Replace('POSTGRES_USER=', 'POSTGRES_USER=maizedoctor_dev')
    $template = $template.Replace('POSTGRES_PASSWORD=', "POSTGRES_PASSWORD=$password")
    [IO.File]::WriteAllText($infrastructureEnv, $template, $utf8)
}
$settings = @{}
foreach ($line in Get-Content -LiteralPath $infrastructureEnv) {
    if ($line -match '^([A-Z_]+)=(.*)$') { $settings[$Matches[1]] = $Matches[2] }
}
foreach ($key in @('POSTGRES_USER', 'POSTGRES_PASSWORD', 'POSTGRES_DB', 'POSTGRES_PORT')) {
    if ([string]::IsNullOrWhiteSpace($settings[$key])) { throw "Set $key in infrastructure/.env first." }
}
$databaseUrl = 'postgresql://{0}:{1}@127.0.0.1:{2}/{3}' -f (
    [Uri]::EscapeDataString($settings['POSTGRES_USER']),
    [Uri]::EscapeDataString($settings['POSTGRES_PASSWORD']),
    $settings['POSTGRES_PORT'],
    [Uri]::EscapeDataString($settings['POSTGRES_DB'])
)
foreach ($component in @('backend', 'ai-service')) {
    $destination = Join-Path $repositoryRoot "$component/.env"
    if (-not (Test-Path -LiteralPath $destination)) {
        $template = [IO.File]::ReadAllText((Join-Path $repositoryRoot "$component/.env.example"))
        $template = $template.Replace('DATABASE_URL=', "DATABASE_URL=$databaseUrl")
        [IO.File]::WriteAllText($destination, $template, $utf8)
    }
}
& (Join-Path $PSScriptRoot 'initialize-auth-env.ps1')
Write-Output 'Local environment files are ready. Existing files were preserved; credentials were not printed.'
