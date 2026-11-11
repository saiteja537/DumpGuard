# DumpGuard Demo and Deployment Guide

## 1. Objective

Demonstrate controlled cleanup of old files with an auditable report, then validate the same behavior on a BO non-production Windows Server before considering production.

DumpGuard does not understand SAP BO internals. It applies filesystem rules to files matching configured extensions and age thresholds. Coordinate with SAP BO/Basis and application owners before using it on actual BO dump directories.

## 2. Demo setup (non-production only)

1. Copy the repository to a dedicated local directory, for example `C:\Tools\DumpGuard`.
2. Create the demo watch and log directories:
   ```powershell
   New-Item -ItemType Directory -Force 'C:\ProgramData\DumpGuard\DemoDumps','C:\ProgramData\DumpGuard\ActionLogs'
   ```
3. Keep the committed safe defaults: `dryRun: true`, `keepNewestCount: 1`, and a dedicated demo folder.
4. Validate JSON:
   ```powershell
   Get-Content .\config.json -Raw | ConvertFrom-Json | Format-List
   ```
5. Run the controller from an elevated PowerShell:
   ```powershell
   .\DumpGuard-Control.ps1 -Action Install
   .\DumpGuard-Control.ps1 -Action Status
   ```
6. Create a small synthetic test file:
   ```powershell
   .\Create-Test-Dump.ps1
   ```
7. Wait for one scan interval plus a small buffer. Check the newest report and heartbeat:
   ```powershell
   Get-ChildItem 'C:\ProgramData\DumpGuard\ActionLogs\DumpGuard_*.log' |
     Sort-Object LastWriteTime -Descending | Select-Object -First 1 | Get-Content
   Get-Content 'C:\ProgramData\DumpGuard\ActionLogs\status.txt'
   Test-Path 'C:\ProgramData\DumpGuard\DemoDumps\DumpGuard_Test_*.dmp'
   ```
   The report should show DRY RUN and a `[DRYRUN]` entry. The file should remain present.
8. For a controlled live test, change `dryRun` to `false` only in the isolated demo configuration, ensure the test file is older than `minAgeMinutes`, and confirm the newest-file retention rule. Wait for a scan and verify a `[DELETED]` entry, zero failures, and that the synthetic test file is gone.
9. Restore `dryRun: true` immediately after the live test. Confirm it by parsing the config and reviewing the next heartbeat/report.

**Never point this live test at a production BO dump directory.**

## 3. BO non-production validation

Before testing actual BO dump folders:

- Obtain approval from the BO/Basis owner and the server owner.
- Identify the exact dump directory and confirm whether it contains active, open, or incident-related files.
- Confirm whether SAP support, internal audit, or incident response requires retention of any dump files.
- Agree the age threshold and number of newest files to retain. Do not assume `keepNewestCount: 0` is acceptable.
- Confirm free disk capacity, backup/recovery, access permissions, and monitoring ownership.
- Start with `dryRun: true`. Review every candidate in the generated report with the BO owner.
- Run a controlled live test only against an approved non-production folder containing disposable test files.
- Verify task state, SYSTEM identity, heartbeat freshness, log output, and Windows Task Scheduler operational history.
- Record the test date, server, configuration, result, approver, and rollback outcome.

## 4. Production go/no-go checklist

Production should be **NO-GO** until all items are satisfied:

- [ ] Non-production test completed and evidence reviewed.
- [ ] BO/Basis, Windows, application, and change owners approved the target path and retention policy.
- [ ] Production configuration reviewed line-by-line; no broad paths or unintended recursion.
- [ ] `dryRun: true` baseline report reviewed and signed off.
- [ ] Backup/retention and incident-investigation requirements confirmed.
- [ ] Service identity and ACLs reviewed; SYSTEM access justified.
- [ ] Rollback procedure tested (stop task, restore prior config, preserve logs, recover files from approved backup if needed).
- [ ] Monitoring and on-call owner assigned.
- [ ] Change window and post-change validation agreed.

Only after explicit approval should `dryRun` be set to `false` on the production server. Keep a copy of the approved config and record its hash/change number.

## 5. Operational commands

```powershell
# Status
.\DumpGuard-Control.ps1 -Action Status

# Stop immediately
.\DumpGuard-Control.ps1 -Action Stop

# Re-enable dry-run by editing config.json, then restart if required
.\DumpGuard-Control.ps1 -Action Restart

# Remove the scheduled task (does not remove logs or dump files)
.\DumpGuard-Control.ps1 -Action Uninstall
```

The script reloads config on each scan, so configuration edits are read on the next scan. Do not rely on that for emergency shutdown: stop the scheduled task.

## 6. Evidence to capture for the demo

- Screenshot of the safe demo configuration.
- Task Scheduler task showing the configured task name, trigger, and SYSTEM principal.
- Status output and heartbeat.
- DRY RUN report showing the candidate file.
- Controlled non-production LIVE report showing the synthetic test file deletion.
- Confirmation that the test file no longer exists.
- Before/after free-space measurement, if relevant.

## 7. Important limitations

A successful synthetic test demonstrates only the file-selection and deletion path. It does not prove that every BO-generated dump is safe to delete, that no process is using it, or that the chosen retention policy meets SAP/vendor or company requirements. Production approval remains a separate decision.
