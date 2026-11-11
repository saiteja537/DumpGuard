<#
    DumpGuard-Control.ps1 - install / start / stop / restart / status / uninstall the DumpGuard task.
    Run in an elevated (Administrator) PowerShell from the DumpGuard folder.

      .\DumpGuard-Control.ps1                    -> interactive menu
      .\DumpGuard-Control.ps1 -Action Install    -> create task (auto-start at boot) and start it
      .\DumpGuard-Control.ps1 -Action Start|Stop|Restart|Status|Uninstall

    Developed by Guddanti Sai Teja
#>
param(
    [ValidateSet('Install','Start','Stop','Restart','Status','Uninstall','')]
    [string]$Action = '',
    [string]$TaskName = 'DumpGuard'
)

$ErrorActionPreference = 'Stop'

$ProductName = 'DumpGuard'
$Version     = '1.0'
$Developer   = 'Guddanti Sai Teja'
$LinkedIn    = 'https://www.linkedin.com/in/sai-teja-628082288'   # <-- paste your LinkedIn URL here
$Email       = 'saitejaguddanti999@gmail.com'

function Show-Banner {
    Write-Host '============================================================' -ForegroundColor Cyan
    Write-Host "  $ProductName v$Version"                                      -ForegroundColor White
    Write-Host '  Automated Crash Dump Cleanup Service'                        -ForegroundColor White
    Write-Host '------------------------------------------------------------' -ForegroundColor Cyan
    Write-Host "  Developed by : $Developer"
    Write-Host "  LinkedIn     : $LinkedIn"
    Write-Host "  Email        : $Email"
    Write-Host '  Questions, bugs or improvement ideas? Please get in touch.'  -ForegroundColor Yellow
    Write-Host '============================================================' -ForegroundColor Cyan
    Write-Host ''
}

Show-Banner

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) { Write-Host 'ERROR: Please run this in an elevated (Administrator) PowerShell.' -ForegroundColor Red; exit 1 }

$scriptPath = Join-Path $PSScriptRoot 'DumpGuard.ps1'
$configPath = Join-Path $PSScriptRoot 'config.json'
$legacyTask = 'CrashDumpMonitor'

function Stop-Leftovers {
    Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" -ErrorAction SilentlyContinue |
        Where-Object { $_.CommandLine -like '*DumpGuard.ps1*' -or $_.CommandLine -like '*CrashDumpMonitor.ps1*' } |
        ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
}

function Remove-LegacyTask {
    if (Get-ScheduledTask -TaskName $legacyTask -ErrorAction SilentlyContinue) {
        Stop-ScheduledTask -TaskName $legacyTask -ErrorAction SilentlyContinue
        Unregister-ScheduledTask -TaskName $legacyTask -Confirm:$false
        Write-Host "Removed old task '$legacyTask'." -ForegroundColor Yellow
    }
}

function Install-Task {
    if (-not (Test-Path $scriptPath)) { throw "$scriptPath not found." }
    if (-not (Test-Path $configPath)) { throw "$configPath not found." }
    try { $cfg = Get-Content $configPath -Raw | ConvertFrom-Json } catch { throw "config.json is not valid JSON: $($_.Exception.Message)" }
    foreach ($p in $cfg.watchPaths) {
        if (-not (Test-Path -LiteralPath $p)) { Write-Host "WARNING: watch path does not exist yet: $p" -ForegroundColor Yellow }
    }

    Remove-LegacyTask
    if (Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue) {
        Stop-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
        Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
    }
    Stop-Leftovers

    $action = New-ScheduledTaskAction -Execute 'powershell.exe' `
              -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$scriptPath`"" `
              -WorkingDirectory $PSScriptRoot
    # Trigger 1: at boot. Trigger 2: every 10 min as a watchdog (ignored while already running).
    $t1 = New-ScheduledTaskTrigger -AtStartup
    $t2 = New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(1) -RepetitionInterval (New-TimeSpan -Minutes 10) -RepetitionDuration (New-TimeSpan -Days 3650)
    $settings = New-ScheduledTaskSettingsSet -RestartCount 999 -RestartInterval (New-TimeSpan -Minutes 1) `
              -ExecutionTimeLimit ([TimeSpan]::Zero) -StartWhenAvailable -AllowStartIfOnBatteries `
              -DontStopIfGoingOnBatteries -MultipleInstances IgnoreNew
    $principal = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest

    Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger @($t1,$t2) -Settings $settings -Principal $principal `
        -Description "$ProductName v$Version - monitors folders 24/7 and deletes configured file types. Developed by $Developer ($Email)" | Out-Null
    Start-ScheduledTask -TaskName $TaskName
    Start-Sleep -Seconds 3
    Write-Host "Task '$TaskName' installed and started." -ForegroundColor Green
    Show-Status
}

function Show-Status {
    $t = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
    if (-not $t) { Write-Host "Task '$TaskName' is not installed." -ForegroundColor Yellow; return }
    $i = Get-ScheduledTaskInfo -TaskName $TaskName
    Write-Host "Task      : $TaskName"
    Write-Host "State     : $($t.State)"
    Write-Host "Runs as   : $($t.Principal.UserId)"
    Write-Host "Last run  : $($i.LastRunTime)   (result: $($i.LastTaskResult))"
    if (Test-Path $configPath) {
        $cfg = Get-Content $configPath -Raw | ConvertFrom-Json
        Write-Host "Watching  : $(@($cfg.watchPaths) -join '; ')  [$(@($cfg.extensions) -join ',')]  DryRun=$($cfg.dryRun)"
        $status = Join-Path $cfg.actionLogFolder 'status.txt'
        if (Test-Path $status) { Write-Host "Heartbeat : $((Get-Content $status)[1])" }
        $recent = Get-ChildItem $cfg.actionLogFolder -Filter 'DumpGuard_*.log' -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 3
        if ($recent) { Write-Host 'Recent reports:'; $recent | ForEach-Object { Write-Host "   $($_.FullName)" } }
    }
}

function Invoke-Action([string]$a) {
    switch ($a) {
        'Install'   { Install-Task }
        'Start'     { Start-ScheduledTask -TaskName $TaskName; Start-Sleep 2; Write-Host 'Started.' -ForegroundColor Green; Show-Status }
        'Stop'      { Stop-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue; Stop-Leftovers; Write-Host 'Stopped.' -ForegroundColor Yellow }
        'Restart'   { Stop-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue; Stop-Leftovers; Start-Sleep 2
                      Start-ScheduledTask -TaskName $TaskName; Start-Sleep 2; Write-Host 'Restarted.' -ForegroundColor Green; Show-Status }
        'Status'    { Show-Status }
        'Uninstall' { Stop-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue; Stop-Leftovers
                      Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue
                      Write-Host "Task '$TaskName' removed." -ForegroundColor Green }
    }
}

try {
    if ($Action) { Invoke-Action $Action }
    else {
        do {
            Write-Host '  1) Install / Reinstall    2) Start    3) Stop    4) Restart'
            Write-Host '  5) Status                 6) Uninstall            0) Exit'
            $c = Read-Host 'Choose'
            switch ($c) { '1'{Invoke-Action 'Install'} '2'{Invoke-Action 'Start'} '3'{Invoke-Action 'Stop'}
                          '4'{Invoke-Action 'Restart'} '5'{Invoke-Action 'Status'} '6'{Invoke-Action 'Uninstall'} }
            Write-Host ''
        } while ($c -ne '0')
    }
} catch { Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red; exit 1 }
