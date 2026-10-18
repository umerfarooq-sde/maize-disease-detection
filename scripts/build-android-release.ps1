param(
    [ValidateSet('staging','production')][string]$Environment = 'staging',
    [Parameter(Mandatory=$true)][string]$ApiBaseUrl,
    [ValidateSet('apk','appbundle')][string]$Format = 'appbundle',
    [ValidateRange(1,2100000000)][int]$BuildNumber = 1,
    [switch]$UnsignedVerification
)
$ErrorActionPreference='Stop'
$taskRoot=Split-Path -Parent $PSScriptRoot
$taskApi=[Uri]$ApiBaseUrl
if ($taskApi.Scheme -ne 'https' -or $taskApi.UserInfo -or $taskApi.Query -or $taskApi.Fragment -or $taskApi.AbsolutePath -ne '/api/v1') {
    throw 'Release API_BASE_URL must be an HTTPS origin ending exactly /api/v1.'
}
if ($taskApi.IsLoopback -or $taskApi.Host.EndsWith('.localhost') -or $taskApi.Host -eq 'localhost') {
    throw 'Release builds must not target localhost.'
}
if (-not $UnsignedVerification -and ($taskApi.Host.EndsWith('.invalid') -or $taskApi.Host.EndsWith('.test'))) {
    throw 'Distributable releases require an operator-owned verified API endpoint.'
}
$taskSourceStatus = @(& git -C $taskRoot status --porcelain=v1 --untracked-files=all)
if ($LASTEXITCODE -ne 0) { throw 'Cannot verify release source identity.' }
$taskWorkspaceDirty = $taskSourceStatus.Count -gt 0
if (-not $UnsignedVerification -and $taskWorkspaceDirty) {
    throw 'Distributable releases require a clean committed checkout. Preserve local edits and build in a separate clean checkout.'
}
$taskSigning=@('MAIZEDOCTOR_KEYSTORE_FILE','MAIZEDOCTOR_KEYSTORE_PASSWORD','MAIZEDOCTOR_KEY_ALIAS','MAIZEDOCTOR_KEY_PASSWORD')
if (-not $UnsignedVerification) {
    foreach ($taskName in $taskSigning) { if (-not [Environment]::GetEnvironmentVariable($taskName)) { throw "Missing external signing setting: $taskName" } }
    if (-not (Test-Path -LiteralPath $env:MAIZEDOCTOR_KEYSTORE_FILE -PathType Leaf)) { throw 'External signing keystore does not exist.' }
    if (-not $env:MAIZEDOCTOR_EXPECTED_SIGNER_SHA256 -or $env:MAIZEDOCTOR_EXPECTED_SIGNER_SHA256.Replace(':','') -notmatch '^[A-Fa-f0-9]{64}$') {
        throw 'Expected public signing-certificate SHA256 is required for distribution verification.'
    }
}
. (Join-Path $PSScriptRoot 'use-project-node.ps1')
$taskPrevious=[Environment]::GetEnvironmentVariable('MAIZEDOCTOR_UNSIGNED_VERIFICATION')
try {
    $env:MAIZEDOCTOR_UNSIGNED_VERIFICATION=if ($UnsignedVerification) { 'true' } else { 'false' }
    Push-Location (Join-Path $taskRoot 'mobile')
    try {
        # Only a public URL reaches Dart; keystore settings remain Gradle inputs.
        & node (Join-Path $PSScriptRoot 'run-flutter.mjs') --release-signing build $Format --release --flavor $Environment "--build-number=$BuildNumber" "--dart-define=API_BASE_URL=$ApiBaseUrl"
        if ($LASTEXITCODE -ne 0) { throw 'Android release compilation failed.' }
    } finally { Pop-Location }
    if ($UnsignedVerification) { Write-Output 'UNSIGNED VERIFICATION BUILD ONLY: not signed or approved for distribution.' }
    else { Write-Output 'Release compiled with external signing; verify certificate fingerprint before distribution.' }
    $taskArtifact = if ($Format -eq 'apk') {
        Join-Path $taskRoot "mobile/build/app/outputs/flutter-apk/app-$Environment-release.apk"
    } else {
        Join-Path $taskRoot "mobile/build/app/outputs/bundle/${Environment}Release/app-$Environment-release.aab"
    }
    if (-not (Test-Path -LiteralPath $taskArtifact -PathType Leaf)) { throw 'Expected release output is missing.' }
    $taskFingerprint = $null
    if ($UnsignedVerification) {
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        $taskZip = [System.IO.Compression.ZipFile]::OpenRead($taskArtifact)
        try {
            if (@($taskZip.Entries | Where-Object { $_.FullName -match '^META-INF/[^/]+\.(RSA|DSA|EC|SF)$' }).Count -gt 0) { throw 'Verification output unexpectedly includes a signing identity.' }
        } finally { $taskZip.Dispose() }
    } else {
        if ($Format -eq 'apk') {
            $taskSdk = if ($env:ANDROID_HOME) { $env:ANDROID_HOME } elseif ($env:ANDROID_SDK_ROOT) { $env:ANDROID_SDK_ROOT } else { Join-Path $env:LOCALAPPDATA 'Android/sdk' }
            $taskSigner = Get-ChildItem -Path (Join-Path $taskSdk 'build-tools/*/apksigner.bat') | Sort-Object FullName -Descending | Select-Object -First 1
            if (-not $taskSigner) { throw 'Android apksigner is required for release verification.' }
            $taskVerification = & $taskSigner.FullName verify --print-certs $taskArtifact 2>&1
            if ($LASTEXITCODE -ne 0) { throw 'Release APK signature verification failed.' }
            $taskDigest = [regex]::Match(($taskVerification -join "`n"), 'certificate SHA-256 digest:\s*([a-fA-F0-9]+)')
            $taskFingerprint = $taskDigest.Groups[1].Value
        } else {
            $taskVerification = & jarsigner -verify $taskArtifact 2>&1
            if ($LASTEXITCODE -ne 0 -or ($taskVerification -join "`n") -notmatch 'jar verified') { throw 'Release AAB signature verification failed.' }
            $taskCertificate = & keytool -printcert -jarfile $taskArtifact 2>&1
            if ($LASTEXITCODE -ne 0) { throw 'Cannot inspect AAB signing certificate.' }
            $taskFingerprint = [regex]::Match(($taskCertificate -join "`n"), 'SHA256:\s*([A-Fa-f0-9:]+)').Groups[1].Value.Replace(':','')
        }
        if (-not $taskFingerprint -or $taskFingerprint.ToLowerInvariant() -ne $env:MAIZEDOCTOR_EXPECTED_SIGNER_SHA256.Replace(':','').ToLowerInvariant()) { throw 'Artifact signer does not match the approved public certificate fingerprint.' }
    }
    $taskRevision = (& git -C $taskRoot rev-parse HEAD).Trim()
    $taskVersion = [regex]::Match((Get-Content -LiteralPath (Join-Path $taskRoot 'mobile/pubspec.yaml') -Raw), '(?m)^version:\s*([^\s+]+)').Groups[1].Value
    $taskRelease = Join-Path $taskRoot ('.cache/releases/' + [DateTime]::UtcNow.ToString('yyyyMMddTHHmmssZ') + '-' + [Guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $taskRelease | Out-Null
    $taskName = "maizedoctor-$Environment-$taskVersion-$BuildNumber-$($taskRevision.Substring(0,12))." + $(if ($Format -eq 'apk') { 'apk' } else { 'aab' })
    Copy-Item -LiteralPath $taskArtifact -Destination (Join-Path $taskRelease $taskName)
    @{environment=$Environment;version=$taskVersion;buildNumber=$BuildNumber;commit=$taskRevision;workspaceDirty=$taskWorkspaceDirty;sourceVerification=$(if ($taskWorkspaceDirty) {'DIRTY_WORKSPACE_VERIFICATION_ONLY'} else {'COMMITTED_CHECKOUT'});apiBaseUrl=$ApiBaseUrl;unsignedVerification=[bool]$UnsignedVerification;signerSha256=$taskFingerprint;sha256=(Get-FileHash -LiteralPath $taskArtifact -Algorithm SHA256).Hash.ToLowerInvariant();distributionApproved=$false;artifact=$taskName} | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $taskRelease 'manifest.json')
    Write-Output 'Release artifact and public provenance manifest saved under ignored .cache/releases; distribution approval remains separate.'
} finally {
    [Environment]::SetEnvironmentVariable('MAIZEDOCTOR_UNSIGNED_VERIFICATION',$taskPrevious,'Process')
}
