# Offline contract checks: do not start containers, contact providers or read secrets.
$ErrorActionPreference = 'Stop'
$script = Join-Path $PSScriptRoot 'operations.ps1'
$tokens = $null
$parseErrors = $null
[System.Management.Automation.Language.Parser]::ParseFile($script, [ref]$tokens, [ref]$parseErrors) | Out-Null
if ($parseErrors.Count) { throw 'Operations entry point has PowerShell syntax errors.' }
$actions = @('Prepare', 'Preflight', 'Config', 'Build', 'Start', 'Stop', 'Status', 'Database', 'Migrate', 'Model', 'E2E', 'Cleanup', 'Backup', 'Restore', 'Monitoring')
foreach ($action in $actions) {
    $plan = & $script -Action $action -ShowPlan -SecretsFile 'private fixture.json' -BackupKeyFile 'private fixture.key' -BackupFile 'owned fixture.mdb' | ConvertFrom-Json
    if ($plan.willExecute -or $plan.action -ne $action -or -not $plan.steps.Count) { throw "Invalid execution plan: $action" }
    $arguments = @($plan.steps | ForEach-Object { $_.arguments })
    if ($arguments -contains '--volumes' -or $arguments -contains 'reset' -or $arguments -contains '--insecure') { throw "Unsafe operation: $action" }
    if ($action -eq 'Stop' -and $arguments -notcontains 'stop') { throw 'Stop must preserve volumes and configured grace periods.' }
    if ($action -eq 'Restore' -and $arguments -notcontains 'restore-drill') { throw 'Restore must retain the isolated-target guard.' }
    if ($action -eq 'Migrate' -and $arguments -notcontains 'deploy') { throw 'Migration must remain additive deploy.' }
    if ($action -eq 'Database' -and ($arguments -contains 'dist/database-check.js' -or $arguments -notcontains 'dist/cli/readiness.js')) { throw 'Use the deployed mounted-secret readiness client, not the legacy environment-only probe.' }
    if ($action -eq 'Monitoring' -and ($arguments -contains '-e' -or -not $plan.steps[-1].inputText)) { throw 'Send probe source through stdin for Windows argument safety.' }
}
Write-Output 'PASS: PowerShell syntax and 15 offline operation plans; no live Docker/provider execution claimed.'
