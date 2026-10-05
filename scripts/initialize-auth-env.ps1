# Generate missing local JWT keys without displaying or overwriting credentials.
$ErrorActionPreference = 'Stop'
$envPath = Join-Path (Split-Path -Parent $PSScriptRoot) 'backend/.env'
if (-not (Test-Path -LiteralPath $envPath -PathType Leaf)) { throw 'Initialize backend/.env first.' }
$content = [IO.File]::ReadAllText($envPath)
$updated = $false
foreach ($key in @('JWT_SECRET', 'JWT_REFRESH_SECRET')) {
    $pattern = '(?m)^' + $key + '=([^\r\n]*)\r?$'
    $match = [regex]::Match($content, $pattern)
    if ($match.Success -and -not [string]::IsNullOrWhiteSpace($match.Groups[1].Value)) { continue }
    $keyBytes = New-Object byte[] 64
    $generator = [Security.Cryptography.RandomNumberGenerator]::Create()
    try { $generator.GetBytes($keyBytes) } finally { $generator.Dispose() }
    $value = [Convert]::ToBase64String($keyBytes).TrimEnd('=').Replace('+', '-').Replace('/', '_')
    if ($match.Success) { $content = [regex]::Replace($content, $pattern, "$key=$value") }
    else { $content = $content.TrimEnd() + [Environment]::NewLine + "$key=$value" + [Environment]::NewLine }
    [Array]::Clear($keyBytes, 0, $keyBytes.Length)
    $value = $null
    $updated = $true
}
if ($updated) { [IO.File]::WriteAllText($envPath, $content, (New-Object System.Text.UTF8Encoding($false))) }
Write-Output 'Local JWT keys are ready. Existing nonblank keys were preserved; no credentials were printed.'
