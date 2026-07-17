#!/usr/bin/env bash

# ================================================================
# Topic 127 / exam-new-v3
# Controlled Recipe Tamper Demonstration
#
# Purpose:
#   1. Verify that the approved recipe is initially valid.
#   2. Back up the approved recipe.
#   3. Apply a controlled unauthorized JSON modification.
#   4. Run the recipe integrity validator.
#   5. Treat validator exit code 2 as SUCCESSFUL tamper detection.
#   6. Preserve tampered evidence.
#   7. Restore the original approved recipe.
#   8. Confirm that the restored recipe passes validation.
#
# Expected validator exit codes:
#   0 = recipe integrity verified
#   1 = validator/configuration/runtime failure
#   2 = recipe tampering detected
#
# Usage:
#   chmod +x scripts/simulate_recipe_tamper.sh
#   ./scripts/simulate_recipe_tamper.sh
# ================================================================

set -Eeuo pipefail

# ----------------------------------------------------------------
# Paths and configuration
# ----------------------------------------------------------------

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

VENV_DIR="${VENV_DIR:-${REPO_ROOT}/venv}"
PYTHON_BIN="${PYTHON_BIN:-${VENV_DIR}/bin/python}"

RECIPE_FILE="${RECIPE_FILE:-${REPO_ROOT}/data/approved_recipe.json}"
RECIPE_HASH_FILE="${RECIPE_HASH:-${REPO_ROOT}/data/approved_recipe.sha256}"
VALIDATOR="${REPO_ROOT}/src/recipe_integrity_check.py"

BACKUP_DIR="${REPO_ROOT}/data/backups"
REPORTS_DIR="${REPO_ROOT}/reports"
LOGS_DIR="${REPO_ROOT}/logs"

TIMESTAMP="$(date -u +%Y%m%dT%H%M%SZ)"

BACKUP_FILE="${BACKUP_DIR}/approved_recipe.${TIMESTAMP}.backup.json"
TAMPERED_EVIDENCE_FILE="${REPORTS_DIR}/approved_recipe.${TIMESTAMP}.tampered.json"
LOG_FILE="${LOGS_DIR}/recipe_tamper_simulation.${TIMESTAMP}.log"

ORIGINAL_RECIPE_RESTORED=false
BACKUP_CREATED=false

# ----------------------------------------------------------------
# Output helpers
# ----------------------------------------------------------------

separator() {
    echo "============================================================"
}

section() {
    echo
    separator
    echo "$1"
    separator
}

info() {
    echo "[INFO] $1"
}

success() {
    echo "[SUCCESS] $1"
}

warning() {
    echo "[WARNING] $1"
}

fail() {
    echo
    separator
    echo "ERROR: $1"
    separator
    return 1
}

# ----------------------------------------------------------------
# Restore helper
# ----------------------------------------------------------------

restore_original_recipe() {
    if [[ "${BACKUP_CREATED}" != "true" ]]; then
        return 0
    fi

    if [[ ! -f "${BACKUP_FILE}" ]]; then
        warning "Backup file is unavailable; automatic restore was not possible."
        return 1
    fi

    cp -- "${BACKUP_FILE}" "${RECIPE_FILE}"
    ORIGINAL_RECIPE_RESTORED=true

    echo "Original recipe restored:"
    echo "  ${RECIPE_FILE}"
}

# ----------------------------------------------------------------
# Cleanup trap
#
# The original approved recipe must be restored even if the script
# is interrupted or a later verification step fails.
# ----------------------------------------------------------------

cleanup() {
    local exit_code=$?

    if [[ "${BACKUP_CREATED}" == "true" ]] &&
       [[ "${ORIGINAL_RECIPE_RESTORED}" != "true" ]]; then

        echo
        warning "Restoring original recipe during cleanup..."

        if ! restore_original_recipe; then
            warning "Automatic recipe restoration failed."
            exit_code=1
        fi
    fi

    exit "${exit_code}"
}

trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

# ----------------------------------------------------------------
# Run validator while preserving its exit code
# ----------------------------------------------------------------

run_validator() {
    local validator_exit_code

    set +e
    "${PYTHON_BIN}" "${VALIDATOR}" 2>&1 | tee -a "${LOG_FILE}"
    validator_exit_code=${PIPESTATUS[0]}
    set -e

    return "${validator_exit_code}"
}

# ----------------------------------------------------------------
# Repository setup
# ----------------------------------------------------------------

cd "${REPO_ROOT}"

mkdir -p \
    "${BACKUP_DIR}" \
    "${REPORTS_DIR}" \
    "${LOGS_DIR}"

touch "${LOG_FILE}"

exec > >(tee -a "${LOG_FILE}") 2>&1

section "Topic 127 — Controlled Recipe Tamper Simulation"

echo "Repository root   : ${REPO_ROOT}"
echo "Recipe file       : ${RECIPE_FILE}"
echo "Approved hash file: ${RECIPE_HASH_FILE}"
echo "Validator         : ${VALIDATOR}"
echo "Backup file       : ${BACKUP_FILE}"
echo "Evidence file     : ${TAMPERED_EVIDENCE_FILE}"
echo "Log file          : ${LOG_FILE}"

# ----------------------------------------------------------------
# Step 1: Validate required files and Python environment
# ----------------------------------------------------------------

section "[1/7] Validating prerequisites"

if [[ ! -x "${PYTHON_BIN}" ]]; then
    fail "Virtual-environment Python was not found: ${PYTHON_BIN}"
    exit 1
fi

if [[ ! -f "${RECIPE_FILE}" ]]; then
    fail "Approved recipe file was not found: ${RECIPE_FILE}"
    exit 1
fi

if [[ ! -f "${RECIPE_HASH_FILE}" ]]; then
    fail "Approved recipe hash file was not found: ${RECIPE_HASH_FILE}"
    exit 1
fi

if [[ ! -f "${VALIDATOR}" ]]; then
    fail "Recipe integrity validator was not found: ${VALIDATOR}"
    exit 1
fi

echo "Python executable:"
echo "  ${PYTHON_BIN}"

"${PYTHON_BIN}" --version

success "Required files and Python environment are available."

# ----------------------------------------------------------------
# Step 2: Validate original recipe JSON
# ----------------------------------------------------------------

section "[2/7] Validating original recipe JSON"

"${PYTHON_BIN}" - "${RECIPE_FILE}" <<'PY'
import json
import sys
from pathlib import Path

recipe_path = Path(sys.argv[1])

with recipe_path.open("r", encoding="utf-8") as file:
    json.load(file)

print(f"Original JSON is valid: {recipe_path}")
PY

# ----------------------------------------------------------------
# Step 3: Verify original recipe integrity before tampering
# ----------------------------------------------------------------

section "[3/7] Verifying original approved recipe"

set +e
run_validator
ORIGINAL_VALIDATOR_EXIT_CODE=$?
set -e

case "${ORIGINAL_VALIDATOR_EXIT_CODE}" in
    0)
        success "Original recipe integrity is valid."
        ;;
    2)
        fail "The recipe is already modified before the demonstration."
        echo
        echo "Restore the approved recipe before running this simulation."
        exit 1
        ;;
    *)
        fail "Initial recipe validation failed with exit code ${ORIGINAL_VALIDATOR_EXIT_CODE}."
        exit 1
        ;;
esac

# ----------------------------------------------------------------
# Step 4: Back up approved recipe
# ----------------------------------------------------------------

section "[4/7] Backing up approved recipe"

cp -- "${RECIPE_FILE}" "${BACKUP_FILE}"
BACKUP_CREATED=true

echo "Backup created:"
echo "  ${BACKUP_FILE}"

# ----------------------------------------------------------------
# Step 5: Apply controlled unauthorized modification
#
# The modification preserves valid JSON so that the demonstration
# proves integrity detection rather than merely JSON syntax failure.
# ----------------------------------------------------------------

section "[5/7] Applying controlled unauthorized modification"

"${PYTHON_BIN}" - "${RECIPE_FILE}" <<'PY'
import json
import sys
from datetime import datetime, timezone
from pathlib import Path

recipe_path = Path(sys.argv[1])

with recipe_path.open("r", encoding="utf-8") as file:
    recipe = json.load(file)

if not isinstance(recipe, dict):
    raise SystemExit(
        "ERROR: Approved recipe must contain a top-level JSON object."
    )

recipe["_unauthorized_change_demo"] = {
    "status": "UNAUTHORIZED",
    "reason": "Controlled integrity-validation demonstration",
    "modified_at": datetime.now(timezone.utc).isoformat(),
}

with recipe_path.open("w", encoding="utf-8", newline="\n") as file:
    json.dump(recipe, file, indent=2, sort_keys=True)
    file.write("\n")

print(f"Controlled unauthorized modification applied: {recipe_path}")
PY

# Verify that the modified document remains valid JSON.
"${PYTHON_BIN}" - "${RECIPE_FILE}" <<'PY'
import json
import sys
from pathlib import Path

recipe_path = Path(sys.argv[1])

with recipe_path.open("r", encoding="utf-8") as file:
    json.load(file)

print("Tampered recipe remains valid JSON.")
PY

cp -- "${RECIPE_FILE}" "${TAMPERED_EVIDENCE_FILE}"

echo
echo "Tampered evidence copy created:"
echo "  ${TAMPERED_EVIDENCE_FILE}"

# ----------------------------------------------------------------
# Step 6: Run validator and interpret exit code correctly
# ----------------------------------------------------------------

section "[6/7] Verifying tamper detection"

set +e
run_validator
TAMPER_VALIDATOR_EXIT_CODE=$?
set -e

case "${TAMPER_VALIDATOR_EXIT_CODE}" in
    2)
        success "Recipe tampering was detected as expected."
        echo "Validator exit code: 2 — expected security-detection result."
        ;;
    0)
        fail "Validator returned success but did not detect the tampered recipe."
        exit 1
        ;;
    *)
        fail "Validator failed unexpectedly with exit code ${TAMPER_VALIDATOR_EXIT_CODE}."
        exit "${TAMPER_VALIDATOR_EXIT_CODE}"
        ;;
esac

# Confirm that the incident evidence report exists.
INCIDENT_REPORT="${REPORTS_DIR}/recipe_tamper_incidents.csv"

if [[ ! -s "${INCIDENT_REPORT}" ]]; then
    fail "Tamper incident report was not generated: ${INCIDENT_REPORT}"
    exit 1
fi

if ! grep -q "Manufacturing recipe tampering detected" "${INCIDENT_REPORT}"; then
    fail "Expected tamper incident entry was not found in ${INCIDENT_REPORT}"
    exit 1
fi

success "Recipe tamper incident evidence was generated."

# ----------------------------------------------------------------
# Step 7: Restore and revalidate approved recipe
# ----------------------------------------------------------------

section "[7/7] Restoring and revalidating approved recipe"

restore_original_recipe

# Validate restored JSON.
"${PYTHON_BIN}" - "${RECIPE_FILE}" <<'PY'
import json
import sys
from pathlib import Path

recipe_path = Path(sys.argv[1])

with recipe_path.open("r", encoding="utf-8") as file:
    json.load(file)

print("Restored recipe JSON is valid.")
PY

set +e
run_validator
RESTORED_VALIDATOR_EXIT_CODE=$?
set -e

if [[ "${RESTORED_VALIDATOR_EXIT_CODE}" -ne 0 ]]; then
    fail "Restored recipe failed integrity validation with exit code ${RESTORED_VALIDATOR_EXIT_CODE}."
    exit 1
fi

success "Original approved recipe was restored and verified."

# ----------------------------------------------------------------
# Final result
# ----------------------------------------------------------------

section "Recipe Tamper Demonstration Completed Successfully"

echo "Security-control result:"
echo "  Controlled recipe modification was detected by SHA-256 validation."
echo
echo "Internal validator result:"
echo "  Exit code 2 = recipe-integrity violation detected."
echo
echo "Demonstration result:"
echo "  Detection, evidence generation, restoration and revalidation passed."
echo
echo "Restoration result:"
echo "  Original approved recipe restored and revalidated."
echo
echo "Evidence:"
echo "  ${TAMPERED_EVIDENCE_FILE}"
echo "  ${INCIDENT_REPORT}"
echo
echo "Log:"
echo "  ${LOG_FILE}"
echo

success "Controlled recipe tampering was detected successfully."
success "Tamper incident evidence was generated successfully."
success "Original approved recipe was restored and revalidated."
info "Internal validator exit code 2 was the expected security-detection result."
info "The complete controlled demonstration is returning exit code 0."

exit 0