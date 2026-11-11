============================================================
  DumpGuard v1.0
  Automated Crash Dump Cleanup Service
------------------------------------------------------------
  Developed by : Guddanti Sai Teja
  LinkedIn     : https://www.linkedin.com/in/sai-teja-628082288
  Email        : saitejaguddanti999@gmail.com
  Questions, bugs or improvement ideas? Please get in touch.
============================================================

FILES
  DumpGuard.ps1          24/7 monitor (run by Task Scheduler)
  DumpGuard-Control.ps1  Install / Start / Stop / Restart / Status / Uninstall
  config.json            Settings (edit anytime - no restart needed)

INSTALL (Administrator PowerShell)
  cd <folder where you copied these files>
  Set-ExecutionPolicy -Scope Process Bypass
  .\DumpGuard-Control.ps1 -Action Install

MANAGE
  .\DumpGuard-Control.ps1                   (menu)
  .\DumpGuard-Control.ps1 -Action Start | Stop | Restart | Status | Uninstall

CONFIG (config.json)
  watchPaths           Folders to monitor (multiple allowed)
  extensions           File types to delete, e.g. [".dmp"]
  recurse              true = include sub-folders
  minAgeMinutes        Only delete files older than this (protects dumps still being written)
  keepNewestCount      Always keep the N newest matching files (0 = keep none)
  scanIntervalSeconds  How often to scan
  dryRun               true = report only, false = really delete
  actionLogFolder      Where reports are written (DumpGuard_yyyyMMdd_HHmmss.log + status.txt)
  actionLogKeepDays    Delete old reports after N days

GO-LIVE
  1. Install with dryRun = true and review the reports for a few hours.
  2. Set dryRun = false (and scanIntervalSeconds = 300) when the reports look right.

PROOF IT RUNS VIA TASK SCHEDULER
  Reports and status.txt show: Run as: NT AUTHORITY\SYSTEM | Interactive session: False
