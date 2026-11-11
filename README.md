# DumpGuard

**DumpGuard v1.0** is a PowerShell-based Windows crash dump cleanup service. It monitors configured directories for selected file extensions and applies an age-based cleanup policy. It runs through Windows Task Scheduler and writes action reports and a status heartbeat.

- **Developer:** Guddanti Sai Teja
- **LinkedIn:** [Sai Teja](https://www.linkedin.com/in/sai-teja-628082288)
- **Contact:** saitejaguddanti999@gmail.com

## Repository contents

| File | Purpose |
|---|---|
| `DumpGuard.ps1` | Background monitoring and cleanup loop |
| `DumpGuard-Control.ps1` | Install, start, stop, restart, status, and uninstall controls |
| `config.json` | Runtime configuration; edit for your Windows environment |

## Requirements

- Windows PowerShell with ScheduledTasks and CIM cmdlets available.
- Administrator privileges for installation and task management.
- A configured watch directory and a writable action-log directory.

## Configure before installation

Edit `config.json`. The committed configuration is a safe example: it watches `C:\CrashDumps`, writes logs under `C:\ProgramData\DumpGuard\ActionLogs`, and has `dryRun` enabled. Create or change these directories to match your environment.

| Setting | Description |
|---|---|
| `watchPaths` | One or more directories to monitor |
| `extensions` | File extensions eligible for cleanup, such as `.dmp` |
| `recurse` | Include subdirectories when `true` |
| `minAgeMinutes` | Minimum file age before a file becomes eligible |
| `keepNewestCount` | Number of newest matching files to preserve |
| `scanIntervalSeconds` | Delay between scans |
| `dryRun` | `true` logs what would be deleted; `false` enables deletion |
| `actionLogFolder` | Directory for reports and `status.txt` |
| `actionLogKeepDays` | Retention period for action logs |

**Keep `dryRun` set to `true` initially.** Review the generated reports and verify the target paths and candidate files before setting it to `false`. Cleanup is destructive when dry-run is disabled.

## Install

Open an elevated (Run as Administrator) PowerShell window in the project directory:

```powershell
Set-ExecutionPolicy -Scope Process Bypass
.\DumpGuard-Control.ps1 -Action Install
```

The installer registers a scheduled task named `DumpGuard` to run as `SYSTEM`, then starts it.

## Manage

```powershell
.\DumpGuard-Control.ps1 -Action Status
.\DumpGuard-Control.ps1 -Action Start
.\DumpGuard-Control.ps1 -Action Stop
.\DumpGuard-Control.ps1 -Action Restart
.\DumpGuard-Control.ps1 -Action Uninstall
```

Run the script without `-Action` to open the interactive menu.

## Logs and status

DumpGuard writes timestamped `DumpGuard_*.log` reports and a `status.txt` heartbeat to `actionLogFolder`. Reports include execution identity and whether the PowerShell session is interactive.

## Safety notes

- Review `watchPaths` carefully; do not point it at broad system or user-profile directories without understanding the impact.
- Keep `dryRun: true` until test reports are verified.
- `keepNewestCount: 0` preserves no newest files by count; use a positive number when you need a rolling reserve.
- Test in a non-production directory before enabling deletion on production systems.

## License

No license has been added. All rights are reserved by the author unless a license is added to this repository.
