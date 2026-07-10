#!/usr/bin/env bash

# ================================================================
# Topic 127 / exam-new-v3
# Recipe Tamper Simulation Script
#
# Purpose:
#   Safely simulate an unauthorized modification to the approved
#   manufacturing recipe and run the recipe-integrity validator.
#
# Default behaviour:
#   1. Back up approved_recipe.json
#   2. Make a valid JSON modification
#   3. Run recipe_integrity_check.py
#   4. Preserve evidence in reports/logs
#   5. Restore the original approved recipe automatically
#
# Usage:
#   chmod +x scripts/simulate_recipe_tamper.sh
#   ./scripts/simulate_recipe_tamper.sh
#
# Keep the tampered file after execution:
#   KEEP_TAMPERED=1 ./scripts/simulate_recipe_tamper.sh
#
# Use another virtual environment:
#   VENV_DIR=/path/to/venv ./scripts/simulate_recipe_tamper.sh
# ================================================================

set -Eeuo pipefail

# ----------------------------------------------------------------
# Configuration
# ----------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

VENV_DIR="${VENV_DIR:-${REPO_ROOT}/venv}"

RECIPE_FILE="${RECIPE_FILE:-${REPO_ROOT}/data/approved_recipe.json}"
VALIDATOR_SCRIPT="${VALIDATOR_SCRIPT:-${REPO_ROOT}/src/recipe_integrity_check.py}"

REPORTS_DIR="${REPORTS_DIR:-${REPO_ROOT}/reports}"
LOGS_DIR="${LOGS_DIR:-${REPO_ROOT}/logs}"
BACKUP_DIR="${BACKUP_DIR:-${REPO_ROOT}/data/backups}"

KEEP_TAMPERED="${KEEP_TAMPERED:-0}"

TIMESTAMP="$(date -u +%Y%m%dT%H%M%SZ)"
BACKUP_FILE="${BACKUP_DIR}/approved_recipe.${TIMESTAMP}.backup.json"
TAMPERED_COPY="${REPORTS_DIR}/approved_recipe.${TIMESTAMP}.tampered.json"
LOG_FILE="${LOGS_DIR}/recipe_tamper_simulation.${TIMESTAMP}.log"

ORIGINAL_RESTORED=false
TAMPER_APPLIED=false

# ----------------------------------------------------------------
# Output helpers
# ----------------------------------------------------------------
section() {
    echo
    echo "============================================================"
    echo "$1"
    echo "============================================================"
}

warning() {
    echo
    echo "WARNING: $1"
}

# ----------------------------------------------------------------
# Cleanup and automatic restoration
# ----------------------------------------------------------------
cleanup() {
    local exit_code=$?

    if [[ "${TAMPER_APPLIED}" == "true" ]] &&
       [[ "${KEEP_TAMPERED}" != "1" ]] &&
       [[ -f "${BACKUP_FILE}" ]]; then

        echo
        echo "Restoring original approved recipe..."

        cp "${BACKUP_FILE}" "${RECIPE_FILE}"
        ORIGINAL_RESTORED=true

        echo "Original recipe restored:"
        echo "  ${RECIPE_FILE}"
    fi

    if [[ "${KEEP_TAMPERED}" == "1" ]] &&
       [[ "${TAMPER_APPLIED}" == "true" ]]; then

        echo
        echo "KEEP_TAMPERED=1 was specified."
        echo "The approved recipe remains modified:"
        echo "  ${RECIPE_FILE}"
        echo
        echo "Restore it manually with:"
        echo "  cp '${BACKUP_FILE}' '${RECIPE_FILE}'"
    fi

    exit "${exit_code}"
}

trap cleanup EXIT

# ----------------------------------------------------------------
# Error handler
# ----------------------------------------------------------------
error_handler() {
    local exit_code=$?
    local line_number="${1:-unknown}"

    echo
    echo "============================================================"
    echo "ERROR: Recipe tamper simulation failed"
    echo "Line      : ${line_number}"
    echo "Exit code : ${exit_code}"
    echo "============================================================"

    exit "${exit_code}"
}

trap 'error_handler ${LINENO}' ERR

# ----------------------------------------------------------------
# Repository setup
# ----------------------------------------------------------------
cd "${REPO_ROOT}"

mkdir -p \
    "${REPORTS_DIR}" \
    "${LOGS_DIR}" \
    "${BACKUP_DIR}"

section "Topic 127 — Recipe Tamper Simulation"

echo "Repository root : ${REPO_ROOT}"
echo "Recipe file     : ${RECIPE_FILE}"
echo "Validator       : ${VALIDATOR_SCRIPT}"
echo "Backup file     : ${BACKUP_FILE}"
echo "Log file        : ${LOG_FILE}"

# ----------------------------------------------------------------
# Validate required files
# ----------------------------------------------------------------
if [[ ! -f "${RECIPE_FILE}" ]]; then
    echo
    echo "ERROR: Approved recipe file was not found."
    echo
    echo "Expected location:"
    echo "  ${RECIPE_FILE}"

    exit 1
fi

if [[ ! -f "${VALIDATOR_SCRIPT}" ]]; then
    echo
    echo "ERROR: Recipe integrity validator was not found."
    echo
    echo "Expected location:"
    echo "  ${VALIDATOR_SCRIPT}"

    exit 1
fi

# ----------------------------------------------------------------
# Activate virtual environment
# ----------------------------------------------------------------
section "[1/6] Activating Python virtual environment"

if [[ ! -f "${VENV_DIR}/bin/activate" ]]; then
    echo
    echo "ERROR: Python virtual environment was not found."
    echo
    echo "Expected location:"
    echo "  ${VENV_DIR}"
    echo
    echo "Run:"
    echo "  ./scripts/install_ec2_dependencies.sh"

    exit 1
fi

# shellcheck disable=SC1091
source "${VENV_DIR}/bin/activate"

echo "Python executable:"
python -c 'import sys; print(sys.executable)'

echo
echo "Python version:"
python --version

# ----------------------------------------------------------------
# Validate original JSON
# ----------------------------------------------------------------
section "[2/6] Validating original recipe JSON"

python - "${RECIPE_FILE}" <<'PY'
import json
import sys
from pathlib import Path

recipe_path = Path(sys.argv[1])

with recipe_path.open("r", encoding="utf-8") as file:
    json.load(file)

print(f"Original JSON is valid: {recipe_path}")
PY

# ----------------------------------------------------------------
# Back up original recipe
# ----------------------------------------------------------------
section "[3/6] Backing up approved recipe"

cp "${RECIPE_FILE}" "${BACKUP_FILE}"

echo "Backup created:"
echo "  ${BACKUP_FILE}"

# ----------------------------------------------------------------
# Apply valid JSON tamper
# ----------------------------------------------------------------
section "[4/6] Applying unauthorized recipe modification"

python - "${RECIPE_FILE}" "${TIMESTAMP}" <<'PY'
import json
import sys
from pathlib import Path

recipe_path = Path(sys.argv[1])
timestamp = sys.argv[2]

with recipe_path.open("r", encoding="utf-8") as file:
    recipe = json.load(file)

tamper_record = {
    "status": "unauthorized-change",
    "timestamp_utc": timestamp,
    "source": "simulate_recipe_tamper.sh",
    "description": "Security validation tamper simulation"
}

if isinstance(recipe, dict):
    recipe["_unauthorized_tamper_simulation"] = tamper_record

elif isinstance(recipe, list):
    recipe.append({
        "_unauthorized_tamper_simulation": tamper_record
    })

else:
    recipe = {
        "original_recipe_value": recipe,
        "_unauthorized_tamper_simulation": tamper_record
    }

with recipe_path.open("w", encoding="utf-8", newline="\n") as file:
    json.dump(recipe, file, indent=2, ensure_ascii=False)
    file.write("\n")

print(f"Tamper modification applied to: {recipe_path}")
PY

TAMPER_APPLIED=true

# Preserve a copy for examination evidence before restoration.
cp "${RECIPE_FILE}" "${TAMPERED_COPY}"

echo
echo "Tampered evidence copy created:"
echo "  ${TAMPERED_COPY}"

# Confirm tampered file is still valid JSON.
python -m json.tool "${RECIPE_FILE}" >/dev/null

echo "Tampered recipe remains valid JSON."

# ----------------------------------------------------------------
# Run integrity validator
# ----------------------------------------------------------------
section "[5/6] Running recipe integrity validator"

set +e

python "${VALIDATOR_SCRIPT}" 2>&1 | tee "${LOG_FILE}"
VALIDATOR_EXIT_CODE=${PIPESTATUS[0]}

set -e

echo
echo "Recipe integrity validator exit code:"
echo "  ${VALIDATOR_EXIT_CODE}"

if [[ "${VALIDATOR_EXIT_CODE}" -eq 0 ]]; then
    warning "The validator returned success after the recipe was modified."

    echo
    echo "This may mean one of the following:"
    echo "  1. The validator records tampering in a report but returns 0."
    echo "  2. The integrity baseline is being regenerated automatically."
    echo "  3. The validator is not checking this exact recipe file."
    echo
    echo "Review:"
    echo "  ${LOG_FILE}"
    echo "  ${REPORTS_DIR}"
else
    echo
    echo "Expected security result:"
    echo "The integrity validator returned a non-zero status after"
    echo "the unauthorized recipe change."
fi

# ----------------------------------------------------------------
# Evidence summary
# ----------------------------------------------------------------
section "[6/6] Simulation evidence summary"

echo "Original backup:"
echo "  ${BACKUP_FILE}"

echo
echo "Tampered evidence copy:"
echo "  ${TAMPERED_COPY}"

echo
echo "Validator log:"
echo "  ${LOG_FILE}"

echo
echo "Current recipe:"
echo "  ${RECIPE_FILE}"

if [[ "${KEEP_TAMPERED}" == "1" ]]; then
    echo
    echo "The modified recipe will remain in place."
else
    echo
    echo "The original recipe will now be restored automatically."
fi

echo
echo "============================================================"
echo "Recipe tamper simulation completed."
echo "============================================================"