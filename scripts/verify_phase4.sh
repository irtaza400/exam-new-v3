#!/usr/bin/env bash
set -euo pipefail

REQUIRED=(
  "data/suppliers.json"
  "data/ehs_events.json"
  "src/supply_chain_ledger.py"
  "src/ehs_incident_engine.py"
  "src/compliance_report_generator.py"
  "scripts/run_supply_chain.sh"
  "scripts/run_ehs_engine.sh"
  "scripts/run_compliance_report.sh"
  "docs/PHASE4_RUNBOOK.md"
)

for f in "${REQUIRED[@]}"; do
  if [ ! -f "$f" ]; then
    echo "MISSING: $f"
    exit 1
  fi
  echo "OK: $f"
done

echo "PHASE 4 verification passed."
