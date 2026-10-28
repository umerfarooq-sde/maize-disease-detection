#Requires -Version 5.1
<#
.SYNOPSIS
Run the existing MAIZEDOCTOR staging debug app on a physical USB Android phone.
.EXAMPLE
.\run-on-phone.ps1 -Action Check
.EXAMPLE
.\run-on-phone.ps1 -DeviceId YOUR_ADB_SERIAL
#>
[CmdletBinding()]
param(
    [ValidateSet('Start', 'Check', 'Status', 'Stop')][string]$Action = 'Start',
    [string]$DeviceId,
    [ValidateRange(60, 900)][int]$StartupTimeoutSeconds = 180,
    [switch]$Help
)
$ErrorActionPreference = 'Stop'
if ($Help) {
    Write-Output @'
MAIZEDOCTOR physical Android USB launcher (Windows PowerShell 5.1 / PowerShell 7)
  .\run-on-phone.ps1                         Start services + Flutter, hot reload
  .\run-on-phone.ps1 -Action Check           Read-only config/dependency/device checks
  .\run-on-phone.ps1 -Action Status          Current services, device and owned state
  .\run-on-phone.ps1 -Action Stop            Stop only launcher-owned services/tunnel
  .\run-on-phone.ps1 -DeviceId SERIAL        Required when several phones are present
  .\run-on-phone.ps1 -StartupTimeoutSeconds 300 -Verbose

No Docker. No migrations. Existing environment settings are never rewritten.
Start stays in the terminal: r=hot reload, R=restart, q=quit. Quitting/Ctrl+C
cleans up owned services and reverse rules; preexisting services/rules are retained.
If the terminal is forcibly closed, supervisors stop when its owner exits. Run Stop
to reconcile the saved USB rule. Stop from another terminal does not kill Flutter;
press q/Ctrl+C in its original terminal. Logs: .cache\phone\<session>\*.log.
USB reset: quit, reconnect/unlock/authorize the phone, then run Start again.
'@
    return
}
try {
    . (Join-Path $PSScriptRoot 'scripts/phone-launcher.ps1')
    Invoke-PhoneLauncher -Root $PSScriptRoot -Action $Action -DeviceId $DeviceId -StartupTimeoutSeconds $StartupTimeoutSeconds
} catch {
    # Helpers return bounded safe errors; never dump environment/process command lines.
    Write-Error -Message $_.Exception.Message -ErrorAction Continue
    exit 1
}
