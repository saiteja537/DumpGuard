# DumpGuard — Management Presentation

## Slide 1 — Title
**DumpGuard: Controlled Crash Dump Cleanup for Windows Servers**

Presenter: Guddanti Sai Teja  
Purpose: Demonstrate a controlled approach to managing aged crash-dump files and reclaiming disk space.

**Speaker note:** DumpGuard is a PowerShell scheduled-task utility. It is not an SAP-certified product and does not replace BO/Basis operational controls.

## Slide 2 — Operational problem
- Crash dump files can be large and accumulate over time.
- Accumulation can consume disk capacity and create avoidable operational work.
- Manual cleanup is inconsistent and difficult to evidence.
- Deletion must respect troubleshooting, audit, and retention requirements.

**Speaker note:** We are addressing file accumulation, not claiming to diagnose or prevent BO crashes.

## Slide 3 — Proposed approach
- Monitor explicitly configured folders.
- Filter by file extension and minimum age.
- Preserve a configurable number of newest matching files.
- Run on a schedule through Windows Task Scheduler.
- Record cleanup actions and write a status heartbeat.

**Speaker note:** The rules are configuration-driven. The tool only acts on files matching all configured conditions.

## Slide 4 — How it works
1. Windows Task Scheduler starts DumpGuard under the configured service identity.
2. DumpGuard reads `config.json`.
3. It scans the approved watch paths.
4. It applies extension, age, and newest-file retention rules.
5. It logs dry-run candidates or live deletions.
6. It writes a heartbeat for operational visibility.

## Slide 5 — Controls and safeguards
- Dry-run mode is the default in the repository configuration.
- Dedicated watch and log folders.
- Age threshold and newest-file retention settings.
- Explicit report entries for deleted files and failures.
- Stop/uninstall controls through the management script.

**Speaker note:** Dry-run is mandatory for baseline review. Live deletion requires a separate change approval.

## Slide 6 — Demonstration evidence
- Synthetic test file created in an isolated demo folder.
- Dry-run report identifies the candidate without deleting it.
- Controlled non-production live test deletes the synthetic file.
- Report records file path, size, timestamp, execution identity, and result.
- Heartbeat confirms the most recent scan.

**Speaker note:** The previous local test reclaimed 5 GB with zero reported failures. That is evidence of the tested file-deletion path only, not production certification.

## Slide 7 — Rollout plan
**Stage 1:** Local demo using synthetic data.  
**Stage 2:** BO non-production validation with approved paths and retention policy.  
**Stage 3:** Review evidence with BO/Basis and Windows owners.  
**Stage 4:** Production change only after written approval and rollback readiness.

## Slide 8 — Risks and dependencies
- Incorrect watch path or retention settings can delete needed dumps.
- A file may be needed for active troubleshooting or incident analysis.
- Filesystem age does not prove that a dump is no longer needed or in use.
- SYSTEM permissions and task behavior must be reviewed.
- Monitoring, backups, and ownership must be agreed.

## Slide 9 — Decision requested
Request approval to:
1. Complete controlled validation on BO non-production.
2. Agree the production dump retention policy and target path.
3. Review evidence and rollback readiness.
4. Submit a separate production change for approval.

**No production deletion is requested by this demo.**

## Slide 10 — Success criteria
- No unexpected files selected in dry-run.
- Approved test files handled as expected.
- Zero unexplained deletion failures.
- Fresh heartbeat and readable action logs.
- Retention policy, ownership, monitoring, and rollback documented.
