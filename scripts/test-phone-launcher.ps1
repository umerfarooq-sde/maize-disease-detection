# Offline decision/lifecycle tests. No DB, providers, phone or server is mutated.
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot 'phone-launcher.ps1')
$script:passed = 0
function Assert-Phone([bool]$Condition, [string]$Label) {
    if (-not $Condition) { throw "FAIL: $Label" }
    $script:passed++
    Write-Host "PASS: $Label"
}
function Assert-PhoneThrows([scriptblock]$Operation, [string]$Pattern, [string]$Label) {
    $message = ''
    try { & $Operation } catch { $message = $_.Exception.Message }
    Assert-Phone ($message -like "*$Pattern*") $Label
}
foreach ($file in @('run-on-phone.ps1', 'scripts/phone-launcher.ps1', 'scripts/test-phone-launcher.ps1')) {
    $tokens = $null; $errors = $null
    $null = [System.Management.Automation.Language.Parser]::ParseFile((Join-Path $root $file), [ref]$tokens, [ref]$errors)
    Assert-Phone ($errors.Count -eq 0) "PowerShell syntax: $file"
}
$phone = [pscustomobject]@{ Id = 'physical1'; State = 'device'; Description = 'model:test' }
$other = [pscustomobject]@{ Id = 'physical2'; State = 'device'; Description = 'model:other' }
Assert-PhoneThrows { Select-PhoneDevice @() '' } 'USB DATA cable' 'missing device actionable'
Assert-PhoneThrows { Select-PhoneDevice @($phone, $other) '' } '-DeviceId' 'multiple devices require explicit selection'
Assert-Phone ((Select-PhoneDevice @($phone, $other) 'physical2').Id -eq 'physical2') 'explicit device selected'
Assert-PhoneThrows { Select-PhoneDevice @([pscustomobject]@{ Id='physical'; State='unauthorized' }) '' } 'authorization' 'unauthorized device rejected'
Assert-PhoneThrows { Select-PhoneDevice @([pscustomobject]@{ Id='physical'; State='offline' }) '' } 'offline' 'offline device rejected'
Assert-PhoneThrows { Select-PhoneDevice @([pscustomobject]@{ Id='emulator-5554'; State='device' }) '' } 'Emulators' 'emulator excluded'
Assert-PhoneThrows { Select-PhoneDevice @([pscustomobject]@{ Id='192.168.1.2:5555'; State='device' }) '' } 'wireless' 'wireless ADB excluded'
Assert-Phone ((Get-PhoneReverseDecision @() '4321') -eq 'create') 'absent reverse rule created'
$same = [pscustomobject]@{ Local='tcp:4321'; Remote='tcp:4321' }
$different = [pscustomobject]@{ Local='tcp:4321'; Remote='tcp:9876' }
Assert-Phone ((Get-PhoneReverseDecision @($same) '4321') -eq 'reuse') 'existing exact rule reused'
Assert-PhoneThrows { Get-PhoneReverseDecision @($different) '4321' } 'will not overwrite' 'conflicting reverse never rebound'
Assert-Phone ((Get-PhoneServiceDecision $false $false $false) -eq 'start') 'free port starts service'
Assert-Phone ((Get-PhoneServiceDecision $true $true $true) -eq 'reuse') 'compatible healthy service reused'
Assert-PhoneThrows { Get-PhoneServiceDecision $true $false $true } 'Nothing was terminated' 'unrelated healthy port owner rejected'
Assert-PhoneThrows { Get-PhoneServiceDecision $true $true $false } 'unhealthy' 'unhealthy port owner rejected'
$listener = New-Object System.Net.Sockets.TcpListener([Net.IPAddress]::Loopback, 0)
try {
    $listener.Start()
    $port = $listener.LocalEndpoint.Port
    $found = @(Get-PhoneListener $port)
    Assert-Phone ($found.Count -gt 0) 'actual occupied loopback port detected'
    Assert-Phone (-not (Test-PhoneServiceIdentity @{Root=$root; Node='not-this-powershell.exe'} 'node' $found)) 'actual unrelated listener is never reusable'
} finally { $listener.Stop() }

$python = Join-Path $root 'ai-service/.venv/Scripts/python.exe'
$argument = 'space and "quotes" with $() and trailing\'
$roundtrip = Invoke-PhoneTool $python @('-c', 'import sys,json; print(json.dumps(sys.argv[1]))', $argument) $root
Assert-Phone (($roundtrip.Output | ConvertFrom-Json) -eq $argument) 'native argv quoting preserves shell metacharacters'
$captureTree = Invoke-PhoneTool $python @('-c', 'import subprocess,sys; subprocess.Popen([sys.executable,"-c","import time; time.sleep(30)"]); print("parent completed")') $root 5
Assert-Phone ($captureTree.Code -eq 0 -and $captureTree.Output.Trim() -eq 'parent completed') 'SDK descendant cannot hold output pipes open after parent exits'
Assert-PhoneThrows { Invoke-PhoneTool $python @('-c', 'import time; time.sleep(30)') $root 1 } 'deadline exceeded' 'tool deadline kills only its owned job'
$timeoutMarker = Join-Path $root ('.cache/phone/timeout-' + [guid]::NewGuid().ToString('N') + '.txt')
Assert-PhoneThrows { Invoke-PhoneTool $python @('-c', 'import os,sys,time,pathlib; pathlib.Path(sys.argv[1]).write_text(str(os.getpid())); time.sleep(30)', $timeoutMarker) $root 1 } 'deadline exceeded' 'real tool timeout reported'
if (Test-Path $timeoutMarker) {
    $fixtureId = [int](Get-Content -LiteralPath $timeoutMarker -Raw)
    Assert-Phone (-not (Get-Process -Id $fixtureId -ErrorAction SilentlyContinue)) 'timed-out venv descendant is actually gone'
} else { throw 'Timeout fixture did not start.' }

$directory = Join-Path $root ('.cache/phone/test-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $directory -Force | Out-Null
$context = @{ Root=$root; Cache=$directory; Adb='fixture-adb'; StatePath=(Join-Path $directory 'session.json') }
$script:removedRules = @()
function Invoke-PhoneTool { param($File, $Arguments, $Directory, $Seconds)
    if ($Arguments -contains '--remove') { $script:removedRules += $Arguments[-1] }
    return @{ Code=0; Output='' }
}
function Get-PhoneReverse { param($Context, $DeviceId)
    return @([pscustomobject]@{ Local='tcp:4321'; Remote='tcp:4321' },
             [pscustomobject]@{ Local='tcp:9999'; Remote='tcp:8888' })
}
function Get-PhoneDevices { param($Context)
    return @([pscustomobject]@{ Id='physical1'; State='device'; Description='transport_id:3' })
}
foreach ($owned in @($false, $true)) {
    $session = [guid]::NewGuid().ToString('N')
    New-Item -ItemType Directory -Path (Join-Path $directory $session) | Out-Null
    Write-PhoneState $context.StatePath @{ session=$session; services=@(); deviceId='physical1'; port=4321; reverseOwned=$owned; transportId='3' }
    Stop-PhoneSession $context
    Assert-Phone (-not (Test-Path $context.StatePath)) "safe Stop reconciles state (reverse owned=$owned)"
}
Assert-Phone ($script:removedRules.Count -eq 1 -and $script:removedRules[0] -eq 'tcp:4321') 'only owned exact reverse removed; reused/unrelated preserved'
$session = [guid]::NewGuid().ToString('N')
New-Item -ItemType Directory -Path (Join-Path $directory $session) | Out-Null
Write-PhoneState $context.StatePath @{ session=$session; services=@(); deviceId='physical1'; port=4321; reverseOwned=$true; transportId='2' }
Stop-PhoneSession $context
Assert-Phone ($script:removedRules.Count -eq 1) 'USB transport reset preserves any externally recreated rule'
Stop-PhoneSession $context
Assert-Phone (-not (Test-Path $context.StatePath)) 'repeated Stop idempotent'
Write-PhoneState $context.StatePath @{ session='../unrelated'; services=@(); reverseOwned=$false }
Assert-PhoneThrows { Stop-PhoneSession $context } 'Invalid saved' 'path traversal state rejected'
# No recursive deletion: retain ignored fixture evidence; it contains no secrets.
Write-Host "RESULT: $script:passed passed, 0 failed. Evidence: $directory"
