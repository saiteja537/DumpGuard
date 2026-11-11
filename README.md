# DumpGuard

**DumpGuard v1.0** is a PowerShell-based Windows scheduled-task service that scans configured folders and applies an age-based cleanup policy to selected file extensions (for example, SAP BusinessObjects `.dmp` crash dumps).

- **Developer:** Guddanti Sai Teja
- **LinkedIn:** [Sai Teja](https://www.linkedin.com/in/sai-teja-628082288)
- **Contact:** saitejaguddanti999@gmail.com

> **Release status:** The repository includes a safe demonstration configuration and deployment guidance. A successful synthetic-file test does not establish production readiness. Validate the exact script, permissions, paths, retention policy, backup/recovery expectations, and monitoring on your BO non-production server before requesting production approval.

## Repository contents

| File | Purpose |
|---|---|
| `DumpGuard.ps1` | Background monitoring and cleanup loop |
| `DumpGuard-Control.ps1` | Install, start, stop, restart, status, and uninstall controls |
| `config.json` | Safe demo defaults; customize per server |
| `Create-Test-Dump.ps1` | Creates a small synthetic `.dmp` test file in the configured watch folder |
| `docs/DEMO-AND-DEPLOYMENT.md` | Non-production test and production deployment checklist |
| `docs/MANAGEMENT-PRESENTATION.md` | Management presentation outline and speaker notes |

## Requirements

- Windows Server with Windows PowerShell and the ScheduledTasks module.
- Administrator privileges to install/manage the scheduled task.
- A dedicated dump directory and a writable action-log directory.
- Change-control approval before enabling deletion on a production server.

## Configure before installation

Edit `config.json` for the target server. The committed configuration is intentionally conservative:

- Watches only `C:\ProgramData\DumpGuard\DemoDumps`.
- Includes only `.dmp` files in the top-level folder.
- Requires files to be at least 1 minute old.
- Preserves the newest 1 matching file.
- Scans every 60 seconds.
- Uses `dryRun: true` (no files are deleted).

| Setting | Description |
|---|---|
| `watchPaths` | One or more directories to monitor |
| `extensions` | File extensions eligible for cleanup |
| `recurse` | Include subdirectories when `true` |
| `minAgeMinutes` | Minimum file age before a file becomes eligible |
| `keepNewestCount` | Number of newest matching files to preserve |
| `scanIntervalSeconds` | Delay between scans |
| `dryRun` | `true` reports candidates; `false` enables deletion |
| `actionLogFolder` | Directory for reports and `status.txt` |
| `actionLogKeepDays` | Retention period for action logs |

**Do not copy a production path into the demo configuration without reviewing the consequences.** In particular, `keepNewestCount: 0` preserves no files by count. A low `minAgeMinutes` can make recent dumps eligible quickly. With `dryRun: false`, every file matching all configured conditions can be deleted.

## Install

1. Copy the repository to a dedicated local folder on the Windows server.
2. Edit and validate `config.json`; create the watch and log directories.
3. Start an elevated PowerShell session in the project directory.
4. Install the scheduled task:

```powershell
Set-ExecutionPolicy -Scope Process Bypass
.\DumpGuard-Control.ps1 -Action Install
```

The current control script registers the task to run as `SYSTEM`, with startup and watchdog triggers. Review the task definition and confirm its behavior in Task Scheduler on the target Windows Server before relying on it.

## Manage

```powershell
.\DumpGuard-Control.ps1 -Action Status
.\DumpGuard-Control.ps1 -Action Start
.\DumpGuard-Control.ps1 -Action Stop
.\DumpGuard-Control.ps1 -Action Restart
.\DumpGuard-Control.ps1 -Action Uninstall
```

Run without `-Action` to open the interactive menu.

## Logs and heartbeat

DumpGuard writes timestamped `DumpGuard_*.log` reports and a `status.txt` heartbeat under the configured `actionLogFolder` (not the script directory). Review both after every test. Reports identify DRY RUN versus LIVE mode and list deleted, skipped, and failed files.

## Test and deployment

Follow [Demo and Deployment Guide](docs/DEMO-AND-DEPLOYMENT.md). Use the management outline in [Management Presentation](docs/MANAGEMENT-PRESENTATION.md).

## Known limitations / production gates

- The cleanup script is a simple extension-and-age based file cleaner; it does not inspect whether a BO process still has a dump file open or whether an incident investigation requires retaining it.
- The current implementation uses `SYSTEM`; confirm that this identity has only the required filesystem access and that organizational policy permits it.
- A heartbeat file indicates the script reached its status-writing step; it is not a complete health-monitoring or alerting solution.
- A synthetic test file validates file selection/deletion mechanics only. It does not validate BO dump lifecycle, vendor support requirements, application impact, or recovery procedures.
- Before production, agree a retention policy with BO/Basis and application owners, test on non-prod, verify backups/incident retention, capture rollback steps, and obtain explicit approval.
- No production deployment should be described as certified or vendor-approved based only on these tests.

## License

No license has been added. All rights are reserved by the author unless a license is added to this repository.
