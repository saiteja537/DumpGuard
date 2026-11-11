[CmdletBinding()]
param(
    [string]$ConfigPath = (Join-Path $PSScriptRoot 'config.json'),
    [string]$FileName = ("DumpGuard_Test_{0}.dmp" -f (Get-Date -Format 'yyyyMMdd_HHmmss')),
    [ValidateRange(1, 50)]
    [int]$SizeMB = 1
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath $ConfigPath -PathType Leaf)) {
    throw "Config file not found: $ConfigPath"
}

try {
    $cfg = Get-Content -LiteralPath $ConfigPath -Raw | ConvertFrom-Json
} catch {
    throw "Invalid config JSON: $($_.Exception.Message)"
}

if (-not $cfg.watchPaths -or -not ($cfg.extensions -contains '.dmp')) {
    throw "Config must include at least one watchPath and the .dmp extension."
}

$targetDir = [string]@($cfg.watchPaths)[0]
if (-not (Test-Path -LiteralPath $targetDir -PathType Container)) {
    New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
}

if ([IO.Path]::GetFileName($FileName) -ne $FileName -or [IO.Path]::GetExtension($FileName) -ne '.dmp') {
    throw 'FileName must be a simple file name ending in .dmp.'
}

$target = Join-Path $targetDir $FileName
if (Test-Path -LiteralPath $target) {
    throw "Refusing to overwrite existing file: $target"
}

$bytes = [int64]$SizeMB * 1MB
$stream = [IO.File]::Open($target, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
try {
    $stream.SetLength($bytes)
} finally {
    $stream.Dispose()
}

# Make the synthetic file older than the configured minimum age so it is eligible on the next scan.
$ageMinutes = [Math]::Max(1, [int]$cfg.minAgeMinutes + 1)
[IO.File]::SetLastWriteTime($target, (Get-Date).AddMinutes(-$ageMinutes))

Get-Item -LiteralPath $target | Select-Object FullName, @{Name='SizeMB';Expression={[Math]::Round($_.Length / 1MB, 2)}}, LastWriteTime
Write-Warning "Synthetic test data only; this is not a real SAP BusinessObjects crash dump."
Write-Warning "Create it only in an isolated demo/non-production watch folder."
