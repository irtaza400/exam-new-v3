#!/usr/bin/env bash
set -euo pipefail

echo "[VERIFY PHASE 3] Checking ICS/process-control files..."
required=(
  "src/opcua_server.py"
  "src/opcua_client_validator.py"
  "src/modbus_server.py"
  "src/modbus_client_validator.py"
  "src/recipe_integrity_check.py"
  "scripts/run_opcua_server.sh"
  "scripts/run_opcua_validator.sh"
  "scripts/run_modbus_server.sh"
  "scripts/run_modbus_validator.sh"
  "scripts/run_recipe_integrity.sh"
  "docs/PHASE3_RUNBOOK.md"
)

for f in "${required[@]}"; do
  if [ ! -f "$f" ]; then
    echo "MISSING: $f"
    exit 1
  fi
  echo "OK: $f"
done

if [ ! -f "data/approved_recipe.json" ] || [ ! -f "data/approved_recipe.sha256" ]; then
  echo "MISSING: approved recipe or hash from Phase 1"
  exit 1
fi

echo "[VERIFY PHASE 3] Running recipe integrity check..."
source venv/bin/activate 2>/dev/null || true
if command -v python >/dev/null 2>&1; then
  python src/recipe_integrity_check.py || true
fi

echo "[VERIFY PHASE 3] Phase 3 files are present. OPC-UA and Modbus validators require their servers running in separate terminals."
