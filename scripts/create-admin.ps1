# Operator-only secure prompt; credentials travel through stdin, never CLI arguments.
$ErrorActionPreference = 'Stop'
$backendDirectory = Join-Path (Split-Path -Parent $PSScriptRoot) 'backend'
$adminEmail = Read-Host 'Admin email'
$adminPassword = Read-Host 'Admin password (at least 15 characters)' -AsSecureString
$passwordPointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($adminPassword)
$previousOutputEncoding = $OutputEncoding
$OutputEncoding = New-Object System.Text.UTF8Encoding($false)
try {
    $credentials = @{
        email = $adminEmail
        password = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($passwordPointer)
    } | ConvertTo-Json -Compress
    Push-Location $backendDirectory
    try {
        $credentials | & npm.cmd run admin:create
        if ($LASTEXITCODE -ne 0) { throw 'Admin creation failed.' }
    } finally { Pop-Location }
} finally {
    [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($passwordPointer)
    $credentials = $null
    $OutputEncoding = $previousOutputEncoding
    $adminPassword.Dispose()
}
