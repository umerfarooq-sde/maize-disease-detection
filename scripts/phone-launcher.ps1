# Internal implementation, separated so lifecycle decisions can be tested without a phone.
Set-StrictMode -Version Latest

function ConvertTo-PhoneArgument([string]$Value) {
    # Windows CommandLineToArgvW quoting. ProcessStartInfo does not invoke a shell.
    return '"' + [regex]::Replace([regex]::Replace($Value, '(\\*)"', '$1$1\"'), '(\\+)$', '$1$1') + '"'
}

function Invoke-PhoneTool {
    param([string]$File, [string[]]$Arguments, [string]$Directory, [int]$Seconds = 45)
    $info = New-Object System.Diagnostics.ProcessStartInfo
    # Short-lived tools also get an owned job. SDK grandchildren must not retain
    # output pipes forever after their wrapper exits or survives a deadline.
    $python = Join-Path (Split-Path -Parent $PSScriptRoot) 'ai-service/.venv/Scripts/python.exe'
    $capture = @{ argv = @($File) + $Arguments; cwd = $Directory } | ConvertTo-Json -Compress
    $encoded = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($capture))
    if ([IO.Path]::GetFileName($File) -ieq 'adb.exe') {
        # ADB may create its shared SDK daemon. It must outlive a discovery probe
        # and must never be enrolled in our disposable capture job.
        $info.FileName = $File
        $info.Arguments = ($Arguments | ForEach-Object { ConvertTo-PhoneArgument $_ }) -join ' '
    } else {
        $info.FileName = $python
        $info.Arguments = (@((Join-Path $PSScriptRoot 'phone-service.py'), '--capture', $encoded) | ForEach-Object { ConvertTo-PhoneArgument $_ }) -join ' '
    }
    $info.WorkingDirectory = $Directory
    $info.UseShellExecute = $false
    $info.CreateNoWindow = $true
    $info.RedirectStandardOutput = $true
    $info.RedirectStandardError = $true
    $process = New-Object System.Diagnostics.Process
    $process.StartInfo = $info
    try {
        [void]$process.Start()
        $stdout = $process.StandardOutput.ReadToEndAsync()
        $stderr = $process.StandardError.ReadToEndAsync()
        if (-not $process.WaitForExit($Seconds * 1000)) {
            $process.Kill() # Exact process handle we created; never a PID from saved state.
            [void]$process.WaitForExit(5000)
            throw 'Tool deadline exceeded. Check configured dependency connectivity; no settings were changed.'
        }
        if (-not $stdout.Wait(3000) -or -not $stderr.Wait(3000)) { throw 'Tool output did not close within its deadline; inspect SDK processes.' }
        return @{ Code = $process.ExitCode; Output = $stdout.Result; Error = $stderr.Result }
    } finally { $process.Dispose() }
}

function Invoke-PhoneProbe([hashtable]$Context, [string]$Service, [string]$Action, [int]$Seconds = 45) {
    if ($Service -eq 'node') {
        $result = Invoke-PhoneTool $Context.Node @('--import', 'tsx', '../scripts/phone-backend.mts', $Action) (Join-Path $Context.Root 'backend') $Seconds
    } else {
        $result = Invoke-PhoneTool $Context.Python @((Join-Path $Context.Root 'scripts/phone-ai.py'), $Action) $Context.Root $Seconds
    }
    try { $value = $result.Output.Trim() | ConvertFrom-Json } catch { throw "$Service probe did not return a safe result. Check installed dependencies." }
    if ($result.Code -ne 0 -or -not $value.ok) {
        $detail = if ($Service -eq 'node') { " Stage=$($value.stage), category=$($value.category), elapsed=$($value.elapsedMs)ms." } else { '' }
        throw "$Service $Action check failed: $($value.code).$detail Review the existing service configuration and connectivity."
    }
    return $value.data
}

function Find-PhoneTools([string]$Root, [switch]$CleanupOnly) {
    if ($env:OS -ne 'Windows_NT') { throw 'This launcher requires Windows and PowerShell 5.1 or 7.' }
    $context = @{ Root = $Root; Python = Join-Path $Root 'ai-service/.venv/Scripts/python.exe' }
    if (-not (Test-Path -LiteralPath $context.Python)) { throw 'The existing AI Python environment is required for bounded process ownership checks. Restore it with scripts/setup-python.ps1 -Component ai-service.' }
    if (-not $CleanupOnly) {
    . (Join-Path $Root 'scripts/use-project-node.ps1')
    $node = Get-Command node.exe -ErrorAction SilentlyContinue
    $flutter = Get-Command flutter.bat -ErrorAction SilentlyContinue
    $dart = Get-Command dart.bat -ErrorAction SilentlyContinue
    if (-not $node) { throw 'Node is missing. Run scripts/use-project-node.ps1 or install the version in backend/.node-version.' }
    if (-not $flutter -or -not $dart) { throw 'Install the project Flutter SDK and add its bin directory to PATH (Flutter and Dart are required).' }
    $context.Node = $node.Source
    $version = Invoke-PhoneTool $node.Source @('--version') $Root
    $required = (Get-Content -LiteralPath (Join-Path $Root 'backend/.node-version') -Raw).Trim()
    if ($version.Output.Trim() -ne "v$required") { throw "Select project Node $required with scripts/use-project-node.ps1." }
    foreach ($relative in @('backend/node_modules/tsx/dist/cli.mjs', 'mobile/.dart_tool/package_config.json', 'ai-service/.venv/Scripts/python.exe')) {
        if (-not (Test-Path -LiteralPath (Join-Path $Root $relative))) { throw "Missing $relative. Follow docs/15-development-environment.md; dependencies are not reinstalled automatically." }
    }
    $npm = Join-Path (Split-Path -Parent $node.Source) 'node_modules/npm/bin/npm-cli.js'
    if (-not (Test-Path -LiteralPath $npm)) { throw 'npm is missing from the selected Node SDK.' }
    $context.Npm = $npm
    $npmCheck = Invoke-PhoneTool $node.Source @($npm, 'ls', '--omit=dev', '--depth=0', '--json') (Join-Path $Root 'backend')
    if ($npmCheck.Code -ne 0) { throw 'Backend runtime dependencies are missing or inconsistent. Review npm ls --omit=dev --depth=0 in backend; nothing was installed automatically.' }
    $pythonVersion = Invoke-PhoneTool $context.Python @('--version') $Root
    if ($pythonVersion.Output.Trim() -notmatch '^Python 3\.11\.') { throw 'Use the existing AI-service Python 3.11 environment.' }
    $pythonPaths = Invoke-PhoneTool $context.Python @('-c', 'import sys,json; print(json.dumps([sys.executable,sys._base_executable]))') $Root
    if ($pythonPaths.Code -ne 0) { throw 'Cannot identify the existing AI Python runtime.' }
    $context.AiPythonPaths = ConvertFrom-Json -InputObject $pythonPaths.Output
    }
    $adbCandidates = @()
    $adbCommand = Get-Command adb.exe -ErrorAction SilentlyContinue
    if ($adbCommand) { $adbCandidates += $adbCommand.Source }
    foreach ($sdk in @($env:ANDROID_SDK_ROOT, $env:ANDROID_HOME, (Join-Path $env:LOCALAPPDATA 'Android/sdk'))) {
        if ($sdk) { $adbCandidates += Join-Path $sdk 'platform-tools/adb.exe' }
    }
    $localProperties = Join-Path $Root 'mobile/android/local.properties'
    if (Test-Path -LiteralPath $localProperties) {
        $line = Get-Content -LiteralPath $localProperties | Where-Object { $_ -match '^sdk\.dir=' } | Select-Object -First 1
        if ($line) { $adbCandidates += Join-Path ($line.Substring(8).Replace('\\', '\').Replace('\:', ':')) 'platform-tools/adb.exe' }
    }
    $context.Adb = $adbCandidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
    if (-not $context.Adb -and -not $CleanupOnly) { throw 'ADB is missing. Install Android SDK Platform-Tools; set ANDROID_SDK_ROOT or mobile/android/local.properties.' }
    return $context
}

function Get-PhoneDevices([hashtable]$Context) {
    $result = Invoke-PhoneTool $Context.Adb @('devices', '-l') $Context.Root
    if ($result.Code -ne 0) { throw 'ADB device inspection failed. Check Android Platform-Tools and the USB driver.' }
    foreach ($line in ($result.Output -split '\r?\n')) {
        if ($line -match '^(\S+)\s+(device|unauthorized|offline)\b(.*)$') {
            [pscustomobject]@{ Id = $Matches[1]; State = $Matches[2]; Description = $Matches[3].Trim() }
        }
    }
}

function Select-PhoneDevice([object[]]$Devices, [string]$DeviceId) {
    $physical = @($Devices | Where-Object { $_.Id -notmatch '^emulator-|:' })
    if ($DeviceId) { $physical = @($physical | Where-Object Id -eq $DeviceId) }
    if ($physical.Count -eq 0) { throw 'No matching USB phone. Connect a USB DATA cable, enable Developer options > USB debugging, unlock the phone and accept its RSA authorization. Install its OEM USB driver if absent; run adb devices. Emulators and wireless ADB are not selected.' }
    if ($physical.Count -gt 1) { throw 'Several USB devices are connected. Run again with -DeviceId SERIAL from the device list; no device was selected.' }
    if ($physical[0].State -ne 'device') { throw "Phone is $($physical[0].State). Unlock it, accept USB debugging authorization, reconnect the DATA cable and run Check again." }
    return $physical[0]
}

function Get-PhoneReverse([hashtable]$Context, [string]$DeviceId) {
    $result = Invoke-PhoneTool $Context.Adb @('-s', $DeviceId, 'reverse', '--list') $Context.Root
    if ($result.Code -ne 0) { throw 'USB connection was lost. Reconnect/unlock/authorize, then quit and rerun Start to restore the tunnel.' }
    foreach ($line in ($result.Output -split '\r?\n')) {
        if ($line -match '^\S+\s+(tcp:\d+)\s+(\S+)\s*$') { [pscustomobject]@{ Local = $Matches[1]; Remote = $Matches[2] } }
    }
}

function Get-PhoneReverseDecision([object[]]$Mappings, [string]$Port) {
    $existing = @($Mappings | Where-Object Local -eq "tcp:$Port")
    if ($existing.Count -eq 0) { return 'create' }
    if ($existing.Count -eq 1 -and $existing[0].Remote -eq "tcp:$Port") { return 'reuse' }
    throw 'The selected phone already forwards this port to a different destination. Resolve that mapping explicitly; the launcher will not overwrite it.'
}

function Get-PhoneListener([int]$Port) {
    return @(Get-NetTCPConnection -State Listen -LocalPort $Port -ErrorAction SilentlyContinue)
}

function Test-PhoneServiceIdentity([hashtable]$Context, [string]$Service, [object[]]$Listeners) {
    if ($Listeners.Count -eq 0) { return $false }
    foreach ($processId in @($Listeners | Select-Object -ExpandProperty OwningProcess -Unique)) {
        $process = Get-CimInstance Win32_Process -Filter "ProcessId=$processId" -ErrorAction SilentlyContinue
        if (-not $process) { return $false }
        if ($Service -eq 'ai') {
            # Windows venv python.exe redirects to its base interpreter. Model
            # readiness/authentication is also required before any reuse decision.
            if ($process.ExecutablePath -notin $Context.AiPythonPaths -or $process.CommandLine -notmatch '-m\s+app\.server') { return $false }
        } elseif ($process.ExecutablePath -ine $Context.Node -or $process.CommandLine -notlike "*$($Context.Root)*" -or $process.CommandLine -notmatch 'src[\\/]server\.ts|dist[\\/]server\.js') { return $false }
    }
    return $true
}

function Get-PhoneServiceDecision([bool]$Listening, [bool]$Compatible, [bool]$Healthy) {
    if (-not $Listening) { return 'start' }
    if ($Compatible -and $Healthy) { return 'reuse' }
    throw 'Configured port is occupied by an unrelated or unhealthy service. Nothing was terminated. Inspect the service or port manually, then retry.'
}

function Write-PhoneState([string]$Path, $State) {
    $temporary = "$Path.tmp"
    $State | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $temporary -Encoding UTF8
    Move-Item -LiteralPath $temporary -Destination $Path -Force
}

function Start-PhoneService([hashtable]$Context, [string]$Service, $State, [int]$GraceSeconds) {
    $directory = Join-Path $Context.Cache $State.session
    $specPath = Join-Path $directory "$Service.json"
    if ($Service -eq 'node') {
        $hook = ([uri](Join-Path $Context.Root 'scripts/phone-stop-hook.mjs')).AbsoluteUri
        $argv = @($Context.Node, '--import', $hook, $Context.Npm, 'run', 'dev')
        $working = Join-Path $Context.Root 'backend'
    } else {
        $argv = @((Join-Path $PSHOME 'powershell.exe'), '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', (Join-Path $Context.Root 'scripts/start-ai.ps1'))
        if (-not (Test-Path -LiteralPath $argv[0])) { $argv[0] = (Get-Command powershell.exe).Source }
        $working = $Context.Root
    }
    $spec = @{ session = $State.session; service = $Service; argv = $argv; cwd = $working;
        ownerPid = $State.ownerPid; ownerStarted = $State.ownerStarted;
        lockPath = Join-Path $Context.Cache 'launcher.lock'; sessionStop = Join-Path $directory 'session.stop';
        graceSeconds = $GraceSeconds; drainSeconds = $GraceSeconds; log = Join-Path $directory "$Service.log" }
    if ($Service -eq 'node') {
        $spec.applicationAck = Join-Path $directory 'node-app-stopped'
        $spec.environment = @{ MAIZEDOCTOR_PHONE_SESSION = $State.session;
            MAIZEDOCTOR_PHONE_STOP = Join-Path $directory 'node.stop';
            MAIZEDOCTOR_PHONE_ACK = $spec.applicationAck }
    }
    Write-PhoneState $specPath $spec
    $arguments = @((Join-Path $Context.Root 'scripts/phone-service.py'), '--spec', $specPath)
    $State.services += $Service
    Write-PhoneState $Context.StatePath $State
    $worker = Start-Process -FilePath $Context.Python -ArgumentList (($arguments | ForEach-Object { ConvertTo-PhoneArgument $_ }) -join ' ') -WorkingDirectory $Context.Root -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $directory "$Service-supervisor.log") -RedirectStandardError (Join-Path $directory "$Service-supervisor-error.log")
    Write-Verbose "$Service supervisor PID $($worker.Id); ownership is fenced by a private Job Object."
}

function Wait-PhoneService([hashtable]$Context, [string]$Service, [int]$Seconds) {
    $deadline = [DateTime]::UtcNow.AddSeconds($Seconds)
    $lastSafeError = 'No ready response received.'
    do {
        $remaining = [int][Math]::Ceiling(($deadline - [DateTime]::UtcNow).TotalSeconds)
        if ($remaining -lt 1) { break }
        try { return Invoke-PhoneProbe $Context $Service 'health' ([Math]::Min(45, $remaining)) } catch { $lastSafeError = $_.Exception.Message }
        if (Test-Path -LiteralPath $Context.StatePath) {
            $session = Get-Content -LiteralPath $Context.StatePath -Raw | ConvertFrom-Json
            $directory = Join-Path $Context.Cache $session.session
            if (Test-Path -LiteralPath (Join-Path $directory 'session.stop')) { throw 'Launcher stop requested.' }
            $workerPath = Join-Path $directory "$Service.state.json"
            if (Test-Path -LiteralPath $workerPath) {
                $worker = Get-Content -LiteralPath $workerPath -Raw | ConvertFrom-Json
                if ($worker.status -in @('stopped', 'failed')) { throw "$Service exited during startup. Inspect its retained safe service events in $directory." }
            }
        }
        Start-Sleep -Seconds 2
    } while ([DateTime]::UtcNow -lt $deadline)
    throw "$Service did not become ready within $Seconds seconds. $lastSafeError Logs are retained in $($Context.Cache)."
}

function Stop-PhoneSession([hashtable]$Context) {
    if (-not (Test-Path -LiteralPath $Context.StatePath)) { Write-Host 'No launcher-owned session recorded.'; return }
    $state = Get-Content -LiteralPath $Context.StatePath -Raw | ConvertFrom-Json
    if ($state.session -notmatch '^[a-f0-9]{32}$') { throw 'Invalid saved launcher state; refusing cleanup.' }
    $directory = Join-Path $Context.Cache $state.session
    Set-Content -LiteralPath (Join-Path $directory 'session.stop') -Value $state.session
    foreach ($service in @($state.services)) {
        if ($service -notin @('node', 'ai')) { throw 'Invalid saved service identity; refusing cleanup.' }
        # Stop files are session-specific requests to our supervisor; no kill by saved PID.
        Set-Content -LiteralPath (Join-Path $directory "$service.stop") -Value $state.session
    }
    $deadline = [DateTime]::UtcNow.AddSeconds(75)
    do {
        $running = @()
        foreach ($service in @($state.services)) {
            $path = Join-Path $directory "$service.state.json"
            if (Test-Path -LiteralPath $path) {
                $worker = Get-Content -LiteralPath $path -Raw | ConvertFrom-Json
                if ($worker.status -in @('starting', 'running', 'stopping')) {
                    $identity = Invoke-PhoneTool $Context.Python @((Join-Path $Context.Root 'scripts/phone-service.py'), '--identity', [string]$worker.pid) $Context.Root
                    if ($identity.Output.Trim() -eq $worker.started) { $running += $service }
                }
            }
        }
        if ($running.Count -gt 0) { Start-Sleep -Milliseconds 500 }
    } while ($running.Count -gt 0 -and [DateTime]::UtcNow -lt $deadline)
    if ($running.Count -gt 0) { throw 'Owned services have not stopped yet; state retained. Retry Stop. No unrelated process was terminated.' }
    foreach ($service in @($state.services)) {
        $path = Join-Path $directory "$service.state.json"
        if (Test-Path -LiteralPath $path) {
            $worker = Get-Content -LiteralPath $path -Raw | ConvertFrom-Json
            if ($worker.PSObject.Properties['forced'] -and $worker.forced) { Write-Warning "$service exceeded its graceful drain boundary; only its owned Job Object was terminated. Inspect $directory before retrying a mutation." }
        }
    }
    if ($state.reverseOwned) {
        try {
            $current = @(Get-PhoneDevices $Context | Where-Object { $_.Id -eq $state.deviceId -and $_.State -eq 'device' })
            if ($current.Count -ne 1) { throw 'Selected phone is not reachable.' }
            $sameTransport = $current[0].Description -match "(?:^|\s)transport_id:$($state.transportId)(?:\s|$)"
            $mapping = @(Get-PhoneReverse $Context $state.deviceId | Where-Object { $_.Local -eq "tcp:$($state.port)" -and $_.Remote -eq "tcp:$($state.port)" })
            if ($sameTransport -and $mapping.Count -eq 1) {
                $result = Invoke-PhoneTool $Context.Adb @('-s', $state.deviceId, 'reverse', '--remove', "tcp:$($state.port)") $Context.Root
                if ($result.Code -ne 0) { throw 'USB rule removal failed.' }
            }
            if (-not $sameTransport) { Write-Host 'USB transport changed; previous rules were lost. Any replacement mapping is unowned and has been preserved.' }
        } catch { throw 'Services stopped. USB cleanup could not be confirmed; reconnect the same phone and run Stop again. Saved ownership retained.' }
    }
    Remove-Item -LiteralPath $Context.StatePath
    Write-Host 'Owned services/tunnel stopped. Reused services, other USB rules, database and provider assets preserved.'
}

function Invoke-PhoneLauncher {
    param([string]$Root, [string]$Action, [string]$DeviceId, [int]$StartupTimeoutSeconds)
    $context = Find-PhoneTools $Root -CleanupOnly:($Action -eq 'Stop')
    $context.Cache = Join-Path $Root '.cache/phone'
    $context.StatePath = Join-Path $context.Cache 'session.json'
    if ($Action -eq 'Stop') { Stop-PhoneSession $context; return }
    Write-Host 'Checking Node.js and actual backend configuration...'
    $node = Invoke-PhoneProbe $context 'node' 'config'
    Write-Host 'Checking FastAPI configuration and approved checkpoint/metadata hashes...'
    $ai = Invoke-PhoneProbe $context 'ai' 'config'
    $aiUri = [uri]$node.aiOrigin
    if ($aiUri.Port -ne $ai.port -or $node.modelVersion -ne $ai.modelVersion -or $node.preprocessingVersion -ne $ai.preprocessingVersion) { throw 'Node and AI service configuration disagree. Correct the existing settings explicitly.' }
    Write-Host "NODE: $($node.origin) | AI (internal only): $($ai.origin)"
    Write-Host "MODEL: $($ai.modelVersion), shared full-frame $($ai.preprocessingVersion), T=1 / null threshold"
    Write-Host 'Checking Android device...'
    $devices = @(Get-PhoneDevices $context)
    if ($devices.Count -eq 0) { Write-Host 'DEVICE: none detected. Connect/unlock a USB-debugging-authorized phone.' }
    foreach ($item in $devices) { Write-Host "DEVICE: $($item.Id) $($item.State) $($item.Description)" }
    foreach ($service in @('node', 'ai')) {
        $port = if ($service -eq 'node') { $node.port } else { $ai.port }
        $listeners = @(Get-PhoneListener $port)
        $healthy = $false
        if ($listeners.Count -gt 0) {
            try { $null = Invoke-PhoneProbe $context $service 'health'; $healthy = $true } catch { Write-Host $_.Exception.Message }
        }
        Write-Host "$($service.ToUpper()): listeners=$($listeners.Count), healthy=$healthy"
        if ($Action -ne 'Status' -and $listeners.Count -gt 0) {
            $compatible = Test-PhoneServiceIdentity $context $service $listeners
            if (-not $compatible -or $Action -eq 'Check') {
                $null = Get-PhoneServiceDecision $true $compatible $healthy
            }
        }
    }
    if (Test-Path -LiteralPath $context.StatePath) { Write-Host "OWNED STATE: $($context.StatePath) (Stop reconciles this session)" }
    if ($Action -eq 'Status') {
        foreach ($item in @($devices | Where-Object State -eq 'device')) {
            foreach ($mapping in @(Get-PhoneReverse $context $item.Id)) { Write-Host "ADB $($item.Id): $($mapping.Local) -> $($mapping.Remote)" }
        }
        Write-Host "LOGS: $($context.Cache)\<session>\*.log"
        return
    }
    Write-Host 'Checking Flutter/Dart/Android toolchain (server secrets are excluded)...'
    $wrapper = Join-Path $Root 'scripts/run-flutter.mjs'
    $mobile = Join-Path $Root 'mobile'
    $doctor = Invoke-PhoneTool $context.Node @($wrapper, 'doctor') $mobile 120
    Write-Host $doctor.Output
    if ($doctor.Code -ne 0) { throw 'flutter doctor failed. Resolve its Android toolchain errors before Start.' }
    if ($doctor.Output -match '\[X\]\s+Android toolchain') { throw 'Flutter reports a missing Android toolchain. Install the Android SDK components identified by flutter doctor before Start.' }
    if ($doctor.Output -match 'licenses not accepted') { Write-Warning 'Review outstanding Android SDK licenses with: node scripts/run-flutter.mjs doctor --android-licenses. Licenses are not accepted automatically.' }
    $flutterDevices = Invoke-PhoneTool $context.Node @($wrapper, 'devices', '--machine') $mobile 60
    if ($flutterDevices.Code -ne 0) { throw 'Flutter device discovery failed.' }
    # Services can be verified even when the phone is not yet attached.
    Write-Host 'Checking configured PostgreSQL, model registry, pgvector and Redis (if configured)...'
    $dependencies = Invoke-PhoneProbe $context 'node' 'dependencies'
    $ragDatabase = Invoke-PhoneProbe $context 'ai' 'database'
    Write-Host "DB: $($dependencies.database); registry: $($dependencies.modelRegistry); pgvector: $($dependencies.pgvector); Redis: $($dependencies.redis); RAG SQL: $($ragDatabase.ragDatabase)"
    Write-Host "Cloudinary credentials configured: $($node.cloudinaryConfigured); retrieval: $($ai.ragConfigured); generation: $($ai.generationConfigured). Provider availability NOT live-verified (no paid/provider requests)."
    if (-not $node.cloudinaryConfigured -or -not $ai.ragConfigured -or -not $ai.generationConfigured) { throw 'Complete phone testing requires existing Cloudinary/RAG/generation configuration. Populate the documented server-only settings; nothing was overwritten.' }
    $device = Select-PhoneDevice $devices $DeviceId
    $qemu = Invoke-PhoneTool $context.Adb @('-s', $device.Id, 'shell', 'getprop', 'ro.kernel.qemu') $Root
    if ($qemu.Code -ne 0 -or $qemu.Output.Trim() -eq '1') { throw 'Selected device is not a reachable physical Android phone.' }
    $listedDevices = ConvertFrom-Json -InputObject $flutterDevices.Output
    $supported = @($listedDevices | Where-Object { $_.id -eq $device.Id -and -not $_.emulator -and $_.isSupported -and $_.targetPlatform -like 'android*' })
    if ($supported.Count -ne 1) { throw 'Selected phone is not supported by Flutter Android debugging. Review flutter doctor/devices and SDK/API compatibility.' }
    $mappings = @(Get-PhoneReverse $context $device.Id)
    $reverseDecision = Get-PhoneReverseDecision $mappings ([string]$node.port)
    if ($Action -eq 'Check') { Write-Host "CHECK PASSED. Phone $($device.Id); USB rule would $reverseDecision. No services or rules were changed."; return }
    New-Item -ItemType Directory -Path $context.Cache -Force | Out-Null
    $lock = $null
    $ownsSession = $false
    try {
        try { $lock = [IO.File]::Open((Join-Path $context.Cache 'launcher.lock'), 'OpenOrCreate', 'ReadWrite', 'None') } catch { throw 'Another Start launcher is active. Use its terminal, or Stop it and quit Flutter first.' }
        if (Test-Path -LiteralPath $context.StatePath) { throw 'An earlier session needs reconciliation. Run -Action Stop, then Start again.' }
        $session = [guid]::NewGuid().ToString('N')
        $directory = Join-Path $context.Cache $session
        New-Item -ItemType Directory -Path $directory | Out-Null
        $owner = Invoke-PhoneTool $context.Python @((Join-Path $Root 'scripts/phone-service.py'), '--identity', [string]$PID) $Root
        if ($owner.Code -ne 0 -or $owner.Output.Trim() -notmatch '^\d+$') { throw 'Cannot fence launcher ownership; no service was started.' }
        $state = @{ session = $session; ownerPid = $PID; ownerStarted = $owner.Output.Trim(); services = @(); deviceId = $device.Id; port = $node.port; reverseOwned = $false }
        Write-PhoneState $context.StatePath $state
        $ownsSession = $true
        foreach ($service in @('ai', 'node')) {
            if (Test-Path -LiteralPath (Join-Path $directory 'session.stop')) { throw 'Launcher stop requested.' }
            $port = if ($service -eq 'node') { $node.port } else { $ai.port }
            $listeners = @(Get-PhoneListener $port)
            $healthy = $false
            if ($listeners.Count -gt 0) { try { $null = Invoke-PhoneProbe $context $service 'health'; $healthy = $true } catch {} }
            $compatible = Test-PhoneServiceIdentity $context $service $listeners
            $decision = Get-PhoneServiceDecision ($listeners.Count -gt 0) $compatible $healthy
            if ($decision -eq 'reuse') { Write-Host "Reusing verified $service; no ownership claimed." } else {
                Write-Host "Starting $service; readiness deadline $StartupTimeoutSeconds seconds..."
                Start-PhoneService $context $service $state ([Math]::Max(20, [int]$node.shutdownSeconds + 5))
                $null = Wait-PhoneService $context $service $StartupTimeoutSeconds
            }
        }
        Write-Host 'Establishing USB connection...'
        if (Test-Path -LiteralPath (Join-Path $directory 'session.stop')) { throw 'Launcher stop requested.' }
        # Recheck immediately before creation; --no-rebind prevents overwriting races.
        $reverseDecision = Get-PhoneReverseDecision @(Get-PhoneReverse $context $device.Id) ([string]$node.port)
        if ($reverseDecision -eq 'create') {
            $current = Select-PhoneDevice @(Get-PhoneDevices $context) $device.Id
            if ($current.Description -notmatch '(?:^|\s)transport_id:(\d+)(?:\s|$)') { throw 'ADB transport identity is unavailable. Update Android SDK Platform-Tools before creating an owned tunnel.' }
            $state.transportId = $Matches[1]
            $state.reversePending = $true
            Write-PhoneState $context.StatePath $state
            $reverse = Invoke-PhoneTool $context.Adb @('-s', $device.Id, 'reverse', '--no-rebind', "tcp:$($node.port)", "tcp:$($node.port)") $Root
            if ($reverse.Code -ne 0) {
                # Never remove a mapping if create was rejected (e.g. competing owner).
                $state.reverseOwned = $false; Write-PhoneState $context.StatePath $state
                throw 'ADB reverse creation failed without rebinding. Inspect the device and existing rules.'
            }
            # Claim ownership only after acknowledgement. If interrupted earlier,
            # an uncertain rule is preserved rather than deleting someone else's.
            $state.reversePending = $false
            $state.reverseOwned = $true
            Write-PhoneState $context.StatePath $state
        }
        if ((Get-PhoneReverseDecision @(Get-PhoneReverse $context $device.Id) ([string]$node.port)) -ne 'reuse') { throw 'ADB reverse verification failed.' }
        $null = Invoke-PhoneProbe $context 'node' 'health'
        $base = "http://127.0.0.1:$($node.port)/api/v1"
        Write-Host "DEVICE: $($device.Id) $($device.Description)"
        Write-Host "NODE: $($node.origin) ready | AI: $($ai.origin) authenticated/model ready"
        Write-Host "ADB: tcp:$($node.port) -> tcp:$($node.port) ($reverseDecision)"
        Write-Host "FLUTTER: staging debug; API_BASE_URL=$base"
        Write-Host "LOGS: $directory\node.log and $directory\ai.log (only owned services); Flutter logs remain in this terminal."
        Write-Host 'Starting Flutter. r=hot reload, R=restart, q=quit. USB reset: quit, reconnect, rerun Start.'
        Push-Location $mobile
        try {
            & $context.Node $wrapper run '--debug' '--flavor' 'staging' '-d' $device.Id "--dart-define=API_BASE_URL=$base"
            if ($LASTEXITCODE -ne 0) { throw 'Flutter exited unsuccessfully. Review terminal output; owned services will be stopped.' }
        } finally { Pop-Location }
    } finally {
        try { if ($ownsSession) { Stop-PhoneSession $context } } finally { if ($lock) { $lock.Dispose() } }
    }
}
