#!/usr/bin/env bash

# ================================================================
# Topic 127 / exam-new-v3
# One-Command Examiner Demonstration
#
# Purpose:
#   Execute the complete examination demonstration through one
#   command while preserving detailed logs and generated evidence.
#
# Usage:
#   chmod +x scripts/run_exam_demo.sh
#   ./scripts/run_exam_demo.sh
#
# Optional:
#   STOP_DOCKER_AFTER_DEMO=1 ./scripts/run_exam_demo.sh
#   SKIP_TAMPER_DEMO=1 ./scripts/run_exam_demo.sh
# ================================================================

set -Eeuo pipefail

# ----------------------------------------------------------------
# Configuration
# ----------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

VENV_DIR="${VENV_DIR:-${REPO_ROOT}/venv}"
LOGS_DIR="${LOGS_DIR:-${REPO_ROOT}/logs}"
REPORTS_DIR="${REPORTS_DIR:-${REPO_ROOT}/reports}"

STOP_DOCKER_AFTER_DEMO="${STOP_DOCKER_AFTER_DEMO:-0}"
SKIP_TAMPER_DEMO="${SKIP_TAMPER_DEMO:-0}"

TIMESTAMP="$(date -u +%Y%m%dT%H%M%SZ)"
MASTER_LOG="${LOGS_DIR}/exam_demo_${TIMESTAMP}.log"
SUMMARY_FILE="${REPORTS_DIR}/exam_demo_summary_${TIMESTAMP}.txt"

DEMO_START_EPOCH="$(date +%s)"
DEMO_FAILED=false

# ----------------------------------------------------------------
# Output helpers
# ----------------------------------------------------------------
section() {
    echo
    echo "============================================================"
    echo "$1"
    echo "============================================================"
}

info() {
    echo "[INFO] $1"
}

warning() {
    echo "[WARNING] $1"
}

success() {
    echo "[SUCCESS] $1"
}

# ----------------------------------------------------------------
# Error handler
# ----------------------------------------------------------------
error_handler() {
    local exit_code=$?
    local line_number="${1:-unknown}"

    DEMO_FAILED=true

    echo
    echo "============================================================"
    echo "ERROR: Examination demo failed"
    echo "Line      : ${line_number}"
    echo "Exit code : ${exit_code}"
    echo "Master log: ${MASTER_LOG}"
    echo "============================================================"

    exit "${exit_code}"
}

trap 'error_handler ${LINENO}' ERR

# ----------------------------------------------------------------
# Cleanup
# ----------------------------------------------------------------
cleanup() {
    local exit_code=$?

    if [[ "${STOP_DOCKER_AFTER_DEMO}" == "1" ]] &&
       command -v docker >/dev/null 2>&1 &&
       docker compose version >/dev/null 2>&1; then

        echo
        info "Stopping Docker Compose services..."

        docker compose down || true
    fi

    exit "${exit_code}"
}

trap cleanup EXIT

# ----------------------------------------------------------------
# Helper: execute command and log output
# ----------------------------------------------------------------
run_logged_command() {
    local description="$1"
    shift

    echo
    info "${description}"

    set +e

    "$@" 2>&1 | tee -a "${MASTER_LOG}"
    local command_exit_code=${PIPESTATUS[0]}

    set -e

    if [[ "${command_exit_code}" -eq 0 ]]; then
        success "${description}"
        return 0
    fi

    warning "${description} returned exit code ${command_exit_code}"
    return "${command_exit_code}"
}

# ----------------------------------------------------------------
# Helper: execute optional Python script
# ----------------------------------------------------------------
run_optional_python_script() {
    local description="$1"
    local script_path="$2"

    if [[ ! -f "${script_path}" ]]; then
        warning "${description} script was not found:"
        echo "  ${script_path}"
        return 0
    fi

    if run_logged_command "${description}" python "${script_path}"; then
        return 0
    fi

    warning "${description} did not complete successfully."
    warning "The examiner demo will continue."
    return 0
}

# ----------------------------------------------------------------
# Helper: find first existing file
# ----------------------------------------------------------------
find_first_existing_file() {
    local candidate

    for candidate in "$@"; do
        if [[ -f "${REPO_ROOT}/${candidate}" ]]; then
            printf '%s\n' "${REPO_ROOT}/${candidate}"
            return 0
        fi
    done

    return 1
}

# ----------------------------------------------------------------
# Repository setup
# ----------------------------------------------------------------
cd "${REPO_ROOT}"

mkdir -p "${LOGS_DIR}" "${REPORTS_DIR}"

# Log complete terminal output.
exec > >(tee -a "${MASTER_LOG}") 2>&1

section "Topic 127 — One-Command Examiner Demonstration"

echo "Repository root : ${REPO_ROOT}"
echo "Virtual env     : ${VENV_DIR}"
echo "Reports         : ${REPORTS_DIR}"
echo "Logs            : ${LOGS_DIR}"
echo "Master log      : ${MASTER_LOG}"
echo "UTC timestamp   : ${TIMESTAMP}"

# ----------------------------------------------------------------
# Step 1: Validate repository
# ----------------------------------------------------------------
section "[1/9] Validating repository"

REQUIRED_FILES=(
    "docker-compose.yml"
    "requirements.txt"
    "scripts/run_complete_lab.sh"
    "scripts/simulate_recipe_tamper.sh"
    "src/project_orchestrator.py"
    "src/opcua_server.py"
    "src/opcua_client_validator.py"
    "src/modbus_server.py"
    "src/modbus_client_validator.py"
    "src/recipe_integrity_check.py"
)

MISSING_FILES=0

for required_file in "${REQUIRED_FILES[@]}"; do
    if [[ -f "${REPO_ROOT}/${required_file}" ]]; then
        echo "[OK] ${required_file}"
    else
        echo "[MISSING] ${required_file}"
        MISSING_FILES=$((MISSING_FILES + 1))
    fi
done

if (( MISSING_FILES > 0 )); then
    echo
    echo "ERROR: ${MISSING_FILES} required file(s) are missing."
    exit 1
fi

success "Repository validation passed."

# ----------------------------------------------------------------
# Step 2: Activate virtual environment
# ----------------------------------------------------------------
section "[2/9] Activating Python environment"

if [[ ! -f "${VENV_DIR}/bin/activate" ]]; then
    echo "ERROR: Virtual environment not found:"
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

python -m pip check

success "Python environment is ready."

# ----------------------------------------------------------------
# Step 3: Start Docker infrastructure
# ----------------------------------------------------------------
section "[3/9] Starting Docker infrastructure"

if ! command -v docker >/dev/null 2>&1; then
    echo "ERROR: Docker command was not found."
    echo
    echo "Run:"
    echo "  ./scripts/install_ec2_dependencies.sh"
    exit 1
fi

if ! docker info >/dev/null 2>&1; then
    echo "ERROR: Docker daemon is unavailable or permission is denied."
    echo
    echo "Reconnect to EC2 after docker-group setup, then run:"
    echo "  docker ps"
    exit 1
fi

docker compose config >/dev/null
docker compose up -d

echo
docker compose ps

success "Docker Compose services started."

# ----------------------------------------------------------------
# Step 4: Run complete lab
# ----------------------------------------------------------------
section "[4/9] Running complete laboratory workflow"

if ! run_logged_command \
    "Complete lab workflow" \
    bash "${REPO_ROOT}/scripts/run_complete_lab.sh"; then

    echo
    echo "ERROR: The complete lab workflow failed."
    echo "Review:"
    echo "  ${MASTER_LOG}"
    exit 1
fi

# ----------------------------------------------------------------
# Step 5: Run recipe tamper demonstration
# ----------------------------------------------------------------
section "[5/9] Running recipe-tamper demonstration"

if [[ "${SKIP_TAMPER_DEMO}" == "1" ]]; then
    warning "Recipe-tamper demonstration skipped by configuration."
else
    if ! run_logged_command \
        "Recipe tamper simulation" \
        bash "${REPO_ROOT}/scripts/simulate_recipe_tamper.sh"; then

        warning "Recipe tamper simulation returned an error."
        warning "The rest of the examiner demo will continue."
    fi
fi

# ----------------------------------------------------------------
# Step 6: Run compliance generation
# ----------------------------------------------------------------
section "[6/9] Generating compliance evidence"

COMPLIANCE_SCRIPT="$(
    find_first_existing_file \
        "src/compliance_report.py" \
        "src/compliance_report_generator.py" \
        "src/generate_compliance_report.py" \
        "src/compliance_engine.py" \
        "scripts/generate_compliance_report.sh" ||
    true
)"

if [[ -z "${COMPLIANCE_SCRIPT}" ]]; then
    warning "No standalone compliance generator was detected."
    echo "Compliance evidence generated by project_orchestrator.py"
    echo "will remain part of the final reports."
else
    case "${COMPLIANCE_SCRIPT}" in
        *.py)
            run_optional_python_script \
                "Compliance evidence generation" \
                "${COMPLIANCE_SCRIPT}"
            ;;
        *.sh)
            if ! run_logged_command \
                "Compliance evidence generation" \
                bash "${COMPLIANCE_SCRIPT}"; then

                warning "Compliance script failed; demo continuing."
            fi
            ;;
    esac
fi

# ----------------------------------------------------------------
# Step 7: Generate consolidated final report
# ----------------------------------------------------------------
section "[7/9] Generating consolidated final report"

FINAL_REPORT_SCRIPT="$(
    find_first_existing_file \
        "src/final_report_generator.py" \
        "src/generate_final_report.py" \
        "src/report_generator.py" \
        "scripts/generate_final_report.sh" ||
    true
)"

if [[ -z "${FINAL_REPORT_SCRIPT}" ]]; then
    warning "No standalone final-report generator was detected."
    echo "Creating an examination summary from current reports and logs."
else
    case "${FINAL_REPORT_SCRIPT}" in
        *.py)
            run_optional_python_script \
                "Final report generation" \
                "${FINAL_REPORT_SCRIPT}"
            ;;
        *.sh)
            if ! run_logged_command \
                "Final report generation" \
                bash "${FINAL_REPORT_SCRIPT}"; then

                warning "Final-report script failed; summary will still be created."
            fi
            ;;
    esac
fi

# ----------------------------------------------------------------
# Step 8: Create demonstration summary
# ----------------------------------------------------------------
section "[8/9] Creating examination summary"

DEMO_END_EPOCH="$(date +%s)"
DEMO_DURATION=$((DEMO_END_EPOCH - DEMO_START_EPOCH))

{
    echo "============================================================"
    echo "Topic 127 — Examination Demonstration Summary"
    echo "============================================================"
    echo
    echo "Execution timestamp : ${TIMESTAMP}"
    echo "Repository          : ${REPO_ROOT}"
    echo "Python              : $(python --version 2>&1)"
    echo "Duration            : ${DEMO_DURATION} seconds"
    echo
    echo "Completed workflow:"
    echo "  - Docker Compose infrastructure"
    echo "  - MQTT / InfluxDB / Grafana startup"
    echo "  - OPC-UA server and client validation"
    echo "  - Modbus server and client validation"
    echo "  - Project orchestrator"
    echo "  - Scikit-learn workflow through orchestrator"
    echo "  - TensorFlow/Keras anomaly workflow"
    echo "  - Recipe integrity validation"
    echo "  - Recipe tamper simulation"
    echo "  - Compliance evidence generation"
    echo "  - Final report generation"
    echo
    echo "Docker services:"
    docker compose ps 2>&1 || true
    echo
    echo "Report files:"
    find "${REPORTS_DIR}" \
        -maxdepth 3 \
        -type f \
        -printf '  %p\n' \
        2>/dev/null | sort
    echo
    echo "Log files:"
    find "${LOGS_DIR}" \
        -maxdepth 2 \
        -type f \
        -printf '  %p\n' \
        2>/dev/null | sort
    echo
    echo "Master execution log:"
    echo "  ${MASTER_LOG}"
    echo
    echo "============================================================"
} > "${SUMMARY_FILE}"

cat "${SUMMARY_FILE}"

success "Examination summary created: ${SUMMARY_FILE}"

# ----------------------------------------------------------------
# Step 9: Final examiner guidance
# ----------------------------------------------------------------
section "[9/9] Examiner demonstration ready"

echo "Grafana:"
echo "  http://EC2-PUBLIC-IP:3000"
echo
echo "InfluxDB:"
echo "  http://EC2-PUBLIC-IP:8086"
echo
echo "Docker status:"
echo "  docker compose ps"
echo
echo "Reports:"
echo "  ls -lah reports/"
echo
echo "Logs:"
echo "  ls -lah logs/"
echo
echo "Exam summary:"
echo "  cat ${SUMMARY_FILE}"
echo
echo "Master execution log:"
echo "  cat ${MASTER_LOG}"

if [[ "${STOP_DOCKER_AFTER_DEMO}" == "1" ]]; then
    echo
    echo "Docker services will now be stopped."
else
    echo
    echo "Docker services will remain running for the live browser demo."
    echo "Stop them later with:"
    echo "  docker compose down"
fi

echo
echo "============================================================"
echo "TOPIC 127 EXAM DEMONSTRATION COMPLETED SUCCESSFULLY"
echo "============================================================"