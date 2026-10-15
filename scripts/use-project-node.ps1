# Process-local SDK selection; never changes machine/user PATH or registry.
$taskRoot = Split-Path -Parent $PSScriptRoot
$taskNodeVersion = (Get-Content -LiteralPath (Join-Path $taskRoot 'backend/.node-version') -Raw).Trim()
if ($taskNodeVersion -notmatch '^24\.[0-9]+\.[0-9]+$') { throw 'Invalid project Node version.' }
$taskNodeDirectory = Join-Path $taskRoot ".cache/node/node-v$taskNodeVersion-win-x64"
if (Test-Path -LiteralPath (Join-Path $taskNodeDirectory 'node.exe')) {
    $env:PATH = "$taskNodeDirectory;$env:PATH"
}
