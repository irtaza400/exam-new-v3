#!/usr/bin/env bash
set -euo pipefail
missing=0
for f in \
  src/audit_logger.py \
  src/incident_manager.py \
  src/devsecops_scan.py \
  src/dashboard_healthcheck.py \
  src/final_report_generator.py \
  src/project_orchestrator.py \
  scripts/run_complete_lab.sh \
  security/security_policy.md \
  docs/PHASE5_RUNBOOK.md \
  docs/EC2_DEPLOYMENT_GUIDE.md \
  docs/GITHUB_UPLOAD_GUIDE.md \
  docs/PRESENTATION_GUIDE.md \
  docs/VIVA_PREPARATION.md; do
  if [ ! -f "$f" ]; then
    echo "MISSING: $f"
    missing=1
  else
    echo "OK: $f"
  fi
done
if [ "$missing" -eq 1 ]; then
  echo "Phase 5 verification failed."
  exit 1
fi
echo "Phase 5 verification passed."
