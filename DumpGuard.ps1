<#
    DumpGuard.ps1  -  Automated Crash Dump Cleanup Service
    Runs 24/7 from Windows Task Scheduler (task name: DumpGuard).
    Reads config.json (same folder) on EVERY scan - config edits apply without restart.

    Developed by Guddanti Sai Teja
#>

$ErrorActionPreference = 'Stop'

# ---------------- Branding ----------------
$ProductName = 'DumpGuard'
$Version     = '1.0'
$Developer   = 'Guddanti Sai Teja'
$LinkedIn    = 'https://www.linkedin.com/in/sai-teja-628082288'   # <-- paste your LinkedIn URL here
$Email       = 'saitejaguddanti999@gmail.com'

function Get-Banner {
@"
============================================================
  $ProductName v$Version
  Automated Crash Dump Cleanup Service
------------------------------------------------------------
  Developed by : $Developer
  LinkedIn     : $LinkedIn
  Email        : $Email
  Questions, bugs or improvement ideas? Please get in touch.
============================================================
"@
}

$ScriptDir  = Split-Path -Parent $MyInvocation.MyCommand.Path
$ConfigFile = Join-Path $ScriptDir 'config.json'

$script:Cfg           = $null
$script:LastConfigErr = $null
$script:LastWarnings  = @{}

function Get-Stamp { Get-Date -Format 'yyyy-MM-dd HH:mm:ss' }

function Get-RunInfo {
    $who = [Security.Principal.WindowsIdentity]::GetCurrent().Name
    "Run as: $who | PID: $PID | Interactive session: $([Environment]::UserInteractive) | Host: $env:COMPUTERNAME"
}

function Write-ActionLog {
    param([string[]]$Lines)
    $folder = if ($script:Cfg) { $script:Cfg.actionLogFolder } else { $ScriptDir }
    New-Item -ItemType Directory -Path $folder -Force | Out-Null
    $stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
    $file  = Join-Path $folder "DumpGuard_$stamp.log"
    $i = 1
    while (Test-Path $file) { $file = Join-Path $folder "DumpGuard_${stamp}_$i.log"; $i++ }
    $Lines | Out-File -FilePath $file -Encoding UTF8
}

function Read-Config {
    try {
        $c = Get-Content -Path $ConfigFile -Raw | ConvertFrom-Json
        foreach ($k in 'watchPaths','extensions','minAgeMinutes','scanIntervalSeconds','dryRun','actionLogFolder') {
            if ($null -eq $c.$k) { throw "Missing key '$k' in config.json" }
        }
        if ($null -eq $c.recurse)           { $c | Add-Member recurse $false }
        if ($null -eq $c.keepNewestCount)   { $c | Add-Member keepNewestCount 0 }
        if ($null -eq $c.actionLogKeepDays) { $c | Add-Member actionLogKeepDays 90 }
        $c.extensions = @($c.extensions | ForEach-Object { $_.ToLower() })
        $script:Cfg = $c
        $script:LastConfigErr = $null
    } catch {
        if ($script:LastConfigErr -ne $_.Exception.Message) {
            $script:LastConfigErr = $_.Exception.Message
            Write-ActionLog -Lines @("[$(Get-Stamp)] [CONFIG-ERROR] $($_.Exception.Message) - using last valid config (if any)")
        }
    }
}

function Test-SafePath {
    param([string]$Path)
    $full = [System.IO.Path]::GetFullPath($Path).TrimEnd('\')
    if ($full -match '^[A-Za-z]:$') { return $false }
    foreach ($bad in @($env:windir, $env:ProgramFiles, ${env:ProgramFiles(x86)}, $env:USERPROFILE, 'C:\Users')) {
        if ($bad -and $full -ieq $bad.TrimEnd('\')) { return $false }
    }
    return $true
}

function Invoke-Cleanup {
    $cfg    = $script:Cfg
    $lines  = New-Object System.Collections.Generic.List[string]
    $count  = 0; $failed = 0; $bytes = 0
    $cutoff = (Get-Date).AddMinutes(-[int]$cfg.minAgeMinutes)

    foreach ($path in @($cfg.watchPaths)) {
        if (-not (Test-Path -LiteralPath $path)) {
            if (-not $script:LastWarnings.ContainsKey($path)) {
                $script:LastWarnings[$path] = $true
                $lines.Add("[$(Get-Stamp)] [WARN] Path not found: $path")
            }
            continue
        }
        $script:LastWarnings.Remove($path)
        if (-not (Test-SafePath $path)) { $lines.Add("[$(Get-Stamp)] [WARN] Unsafe path skipped: $path"); continue }

        $all = @(Get-ChildItem -LiteralPath $path -File -Recurse:([bool]$cfg.recurse) -ErrorAction SilentlyContinue |
                 Where-Object { $cfg.extensions -contains $_.Extension.ToLower() } |
                 Sort-Object LastWriteTime -Descending)

        $candidates = if ([int]$cfg.keepNewestCount -gt 0) { $all | Select-Object -Skip ([int]$cfg.keepNewestCount) } else { $all }
        $candidates = @($candidates | Where-Object { $_.LastWriteTime -lt $cutoff })

        foreach ($f in $candidates) {
            $size = "{0:N1} MB" -f ($f.Length / 1MB)
            try {
                if ($cfg.dryRun) {
                    $lines.Add("[$(Get-Stamp)] [DRYRUN]  Would delete: $($f.FullName) | $size | modified $($f.LastWriteTime)")
                } else {
                    Remove-Item -LiteralPath $f.FullName -Force
                    $lines.Add("[$(Get-Stamp)] [DELETED] $($f.FullName) | $size | modified $($f.LastWriteTime)")
                }
                $count++; $bytes += $f.Length
            } catch {
                $failed++
                $lines.Add("[$(Get-Stamp)] [ERROR]   $($f.FullName) -> $($_.Exception.Message)")
            }
        }
    }

    if ($lines.Count -gt 0) {
        $mode  = if ($cfg.dryRun) { 'DRY RUN' } else { 'LIVE' }
        $drive = Get-PSDrive -Name ($cfg.watchPaths[0].Substring(0,1)) -ErrorAction SilentlyContinue
        $freeGB = if ($drive) { "{0:N1} GB" -f ($drive.Free / 1GB) } else { 'n/a' }
        $header = @(
            "$ProductName v$Version - Cleanup Report - $(Get-Stamp) - $mode",
            "Developed by $Developer | $Email",
            (Get-RunInfo),
            "Files: $count | Failed: $failed | Freed: $("{0:N2}" -f ($bytes / 1GB)) GB | Drive free now: $freeGB",
            ('-' * 80)
        )
        Write-ActionLog -Lines ($header + $lines)
    }
}

function Remove-OldActionLogs {
    $days = [int]$script:Cfg.actionLogKeepDays
    if ($days -le 0) { return }
    Get-ChildItem -Path $script:Cfg.actionLogFolder -Filter 'DumpGuard_*.log' -File -ErrorAction SilentlyContinue |
        Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-$days) } |
        Remove-Item -Force -ErrorAction SilentlyContinue
}

# ---------------- Main ----------------
$banner = Get-Banner
if ([Environment]::UserInteractive) { Write-Host $banner -ForegroundColor Cyan }

Read-Config
if (-not $script:Cfg) { Start-Sleep -Seconds 5; Read-Config }
if ($script:Cfg) {
    Write-ActionLog -Lines (@($banner) + @(
        "[$(Get-Stamp)] [START] $ProductName started.",
        (Get-RunInfo),
        "DryRun=$($script:Cfg.dryRun) | Paths=$(@($script:Cfg.watchPaths) -join '; ') | Ext=$(@($script:Cfg.extensions) -join ',') | MinAge=$($script:Cfg.minAgeMinutes)min | Scan=$($script:Cfg.scanIntervalSeconds)s"))
}

while ($true) {
    Read-Config
    if ($script:Cfg) {
        try {
            Invoke-Cleanup
            Remove-OldActionLogs
            @("$ProductName v$Version - Developed by $Developer", "Last scan: $(Get-Stamp) | DryRun=$($script:Cfg.dryRun)", (Get-RunInfo)) |
                Out-File (Join-Path $script:Cfg.actionLogFolder 'status.txt') -Encoding UTF8
        } catch {
            Write-ActionLog -Lines @("[$(Get-Stamp)] [FATAL] $($_.Exception.Message)")
        }
        $sleep = [Math]::Max(10, [int]$script:Cfg.scanIntervalSeconds)
    } else { $sleep = 30 }
    Start-Sleep -Seconds $sleep
}
