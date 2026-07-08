# Phase 5 Runbook — DevSecOps, Audit, Final Integration

## Purpose
Phase 5 completes the Version 3 enterprise lab by adding DevSecOps scanning, audit logging, incident consolidation, dashboard verification, final evidence reporting, and final project documentation.

## Run
```bash
./scripts/run_complete_lab.sh
```

## Verify
```bash
./scripts/verify_phase5.sh
find reports -maxdepth 1 -type f | sort
```

## Evidence
- reports/security_scan_report.txt
- reports/audit_log.csv
- reports/incident_summary.csv
- reports/dashboard_healthcheck.txt
- reports/final_project_report.md
