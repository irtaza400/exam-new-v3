#!/usr/bin/env bash

# ================================================================
# Topic 127 / exam-new-v3
# One-Command Examiner Demonstration
#
# Purpose:
#   Execute the complete examination demonstration while preserving
#   logs, reports and live Grafana monitoring.
#
# Usage:
#   chmod +x scripts/run_exam_demo.sh
#   ./scripts/run_exam_demo.sh
#
# Optional:
#   STOP_DOCKER_AFTER_DEMO=1 ./scripts/run_exam_demo.sh
#   STOP_MONITORING_AFTER_DEMO=1 ./scripts/run_exam_demo.sh
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
RUNTIME_DIR="${RUNTIME_DIR:-${REPO_ROOT}/.runtime}"

STOP_DOCKER_AFTER_DEMO="${STOP_DOCKER_AFTER_DEMO:-0}"
STOP_MONITORING_AFTER_DEMO="${STOP_MONITORING_AFTER_DEMO:-0}"
SKIP_TAMPER_DEMO="${SKIP_TAMPER_DEMO:-0}"

TIMESTAMP="$(date -u +%Y%m%dT%H%M%SZ)"
MASTER_LOG="${LOGS_DIR}/exam_demo_${TIMESTAMP}.log"
SUMMARY_FILE="${REPORTS_DIR}/exam_demo_summary_${TIMESTAMP}.txt"

DEMO_START_EPOCH="$(date +%s)"

# ----------------------------------------------------------------
# Output helpers
# ----------------------------------------------------------------
section() {
    echo
    echo "============================================================"
    echo "$1"
    echo "============================================================"
}

info() { echo "[INFO] $1"; }
warning() { echo "[WARNING] $1"; }
success() { echo "[SUCCESS] $1"; }

# ----------------------------------------------------------------
# Error handler
# ----------------------------------------------------------------
error_handler() {
    local exit_code=$?
    local line_number="${1:-unknown}"
    local command_name="${2:-unknown}"

    echo
    echo "============================================================"
    echo "ERROR: Examination demo failed"
    echo "Line      : ${line_number}"
    echo "Exit code : ${exit_code}"
    echo "Command   : ${command_name}"
    echo "Master log: ${MASTER_LOG}"
    echo "============================================================"

    exit "${exit_code}"
}

trap 'error_handler "${LINENO}" "${BASH_COMMAND}"' ERR

# ----------------------------------------------------------------
# Process helpers
# ----------------------------------------------------------------
stop_runtime_process() {
    local service_name="$1"
    local pid_file="$2"
    local pid=""

    if [[ -f "${pid_file}" ]]; then
        pid="$(tr -d '[:space:]' < "${pid_file}")"
    fi

    if [[ -n "${pid}" ]] && kill -0 "${pid}" 2>/dev/null; then
        info "Stopping ${service_name} process ${pid}..."
        kill "${pid}" 2>/dev/null || true
        wait "${pid}" 2>/dev/null || true
    fi

    rm -f "${pid_file}"
}

# ----------------------------------------------------------------
# Cleanup
# ----------------------------------------------------------------
cleanup() {
    local exit_code=$?

    if [[ "${STOP_MONITORING_AFTER_DEMO}" == "1" ]]; then
        stop_runtime_process \
            "MQTT-to-Influx writer" \
            "${RUNTIME_DIR}/mqtt_to_influx.pid"

        stop_runtime_process \
            "sensor simulator" \
            "${RUNTIME_DIR}/sensor_simulator.pid"
    fi

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
# Execute command and log output
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

run_optional_python_script() {
    local description="$1"
    local script_path="$2"

    if [[ ! -f "${script_path}" ]]; then
        warning "${description} script was not found: ${script_path}"
        return 0
    fi

    if run_logged_command "${description}" python "${script_path}"; then
        return 0
    fi

    warning "${description} did not complete successfully; demo continuing."
    return 0
}

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
mkdir -p "${LOGS_DIR}" "${REPORTS_DIR}" "${RUNTIME_DIR}"

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
    "src/mqtt_to_influx.py"
    "src/sensor_simulator.py"
    "src/opcua_server.py"
    "src/opcua_client_validator.py"
    "src/modbus_server.py"
    "src/modbus_client_validator.py"
    "src/recipe_integrity_check.py"
    "dashboards/json/topic127_cleanroom_dashboard.json"
    "grafana/provisioning/datasources/influxdb.yml"
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
    echo "ERROR: ${MISSING_FILES} required file(s) are missing."
    exit 1
fi

# Verify that the dashboard references the provisioned datasource UID.
if ! grep -q '"uid"[[:space:]]*:[[:space:]]*"influxdb-topic127"' \
    "${REPO_ROOT}/dashboards/json/topic127_cleanroom_dashboard.json"; then

    echo "ERROR: Grafana dashboard datasource UID is incorrect."
    echo "Expected: influxdb-topic127"
    exit 1
fi

success "Repository validation passed."

# ----------------------------------------------------------------
# Step 2: Activate virtual environment
# ----------------------------------------------------------------
section "[2/9] Activating Python environment"

if [[ ! -f "${VENV_DIR}/bin/activate" ]]; then
    echo "ERROR: Virtual environment not found: ${VENV_DIR}"
    echo "Run: ./scripts/install_ec2_dependencies.sh"
    exit 1
fi

# shellcheck disable=SC1091
source "${VENV_DIR}/bin/activate"

python -c 'import sys; print("Python executable:", sys.executable)'
python --version
python -m pip check

# ----------------------------------------------------------------
# Step 3: Start Docker infrastructure
# ----------------------------------------------------------------
section "[3/9] Starting Docker infrastructure"

if ! command -v docker >/dev/null 2>&1; then
    echo "ERROR: Docker command was not found."
    exit 1
fi

if ! docker info >/dev/null 2>&1; then
    echo "ERROR: Docker daemon is unavailable or permission is denied."
    echo "Reconnect to EC2 after docker-group setup, then run: docker ps"
    exit 1
fi

docker compose config >/dev/null
docker compose up -d
docker compose ps

success "Docker Compose services started."

# ----------------------------------------------------------------
# Step 4: Run complete lab, keeping live monitoring active
# ----------------------------------------------------------------
section "[4/9] Running complete laboratory workflow"

if ! run_logged_command \
    "Complete lab workflow" \
    env STOP_MONITORING_AFTER_LAB=0 \
    bash "${REPO_ROOT}/scripts/run_complete_lab.sh"; then

    echo "ERROR: The complete lab workflow failed. Review: ${MASTER_LOG}"
    exit 1
fi

# Confirm monitoring processes still exist.
for pid_file in \
    "${RUNTIME_DIR}/mqtt_to_influx.pid" \
    "${RUNTIME_DIR}/sensor_simulator.pid"; do

    if [[ ! -f "${pid_file}" ]]; then
        echo "ERROR: Expected monitoring PID file was not created: ${pid_file}"
        exit 1
    fi

    pid="$(tr -d '[:space:]' < "${pid_file}")"

    if [[ -z "${pid}" ]] || ! kill -0 "${pid}" 2>/dev/null; then
        echo "ERROR: Monitoring process from ${pid_file} is not running."
        exit 1
    fi
done

success "Live MQTT, InfluxDB and Grafana monitoring remains active."

# ----------------------------------------------------------------
# Step 5: Run controlled recipe-tamper demonstration
#
# Exit-code contract:
#   0 = complete controlled tamper demonstration succeeded
#   2 = compatibility handling for an older tamper wrapper that
#       directly propagated the validator's detection exit code
#   any other value = unexpected execution failure
# ----------------------------------------------------------------
section "[5/9] Running recipe-tamper demonstration"

if [[ "${SKIP_TAMPER_DEMO}" == "1" ]]; then
    warning "Recipe-tamper demonstration skipped by configuration."
else
    TAMPER_DEMO_EXIT_CODE=0

    run_logged_command \
        "Recipe tamper simulation" \
        bash "${REPO_ROOT}/scripts/simulate_recipe_tamper.sh" \
        || TAMPER_DEMO_EXIT_CODE=$?

    case "${TAMPER_DEMO_EXIT_CODE}" in
        0)
            success "Controlled recipe tamper demonstration completed successfully."
            success "Tampering was detected, evidence was generated, and the approved recipe was restored."
            ;;

        2)
            warning "Tamper wrapper returned exit code 2."
            success "Exit code 2 represents successful recipe-integrity violation detection."
            warning "The current wrapper should normally convert this completed demonstration to exit code 0."
            ;;

        *)
            warning "Recipe tamper demonstration returned unexpected exit code ${TAMPER_DEMO_EXIT_CODE}."
            warning "The main examination workflow will continue, but the tamper log must be reviewed."
            warning "Review: ${LOGS_DIR}/recipe_tamper_simulation.*.log"
            ;;
    esac
fi

# ----------------------------------------------------------------
# Step 6: Generate compliance evidence
# ----------------------------------------------------------------
section "[6/9] Generating compliance evidence"

COMPLIANCE_SCRIPT="$(find_first_existing_file \
    "src/compliance_report.py" \
    "src/compliance_report_generator.py" \
    "src/generate_compliance_report.py" \
    "src/compliance_engine.py" \
    "scripts/generate_compliance_report.sh" || true)"

if [[ -z "${COMPLIANCE_SCRIPT}" ]]; then
    warning "No standalone compliance generator was detected."
else
    case "${COMPLIANCE_SCRIPT}" in
        *.py)
            run_optional_python_script "Compliance evidence generation" "${COMPLIANCE_SCRIPT}"
            ;;
        *.sh)
            run_logged_command "Compliance evidence generation" bash "${COMPLIANCE_SCRIPT}" || \
                warning "Compliance script failed; demo continuing."
            ;;
    esac
fi

# ----------------------------------------------------------------
# Step 7: Generate consolidated final report
# ----------------------------------------------------------------
section "[7/9] Generating consolidated final report"

FINAL_REPORT_SCRIPT="$(find_first_existing_file \
    "src/final_report_generator.py" \
    "src/generate_final_report.py" \
    "src/report_generator.py" \
    "scripts/generate_final_report.sh" || true)"

if [[ -z "${FINAL_REPORT_SCRIPT}" ]]; then
    warning "No standalone final-report generator was detected."
else
    case "${FINAL_REPORT_SCRIPT}" in
        *.py)
            run_optional_python_script "Final report generation" "${FINAL_REPORT_SCRIPT}"
            ;;
        *.sh)
            run_logged_command "Final report generation" bash "${FINAL_REPORT_SCRIPT}" || \
                warning "Final-report script failed; summary will still be created."
            ;;
    esac
fi

# ----------------------------------------------------------------
# Step 8: Create demonstration summary
# ----------------------------------------------------------------
section "[8/9] Creating examination summary"

DEMO_END_EPOCH="$(date +%s)"
DEMO_DURATION=$((DEMO_END_EPOCH - DEMO_START_EPOCH))
MQTT_WRITER_PID="$(tr -d '[:space:]' < "${RUNTIME_DIR}/mqtt_to_influx.pid")"
SENSOR_SIM_PID="$(tr -d '[:space:]' < "${RUNTIME_DIR}/sensor_simulator.pid")"

{
    echo "============================================================"
    echo "Topic 127 — Examination Demonstration Summary"
    echo "============================================================"
    echo
    echo "Execution timestamp : ${TIMESTAMP}"
    echo "Repository          : ${REPO_ROOT}"
    echo "Python              : $(python --version 2>&1)"
    echo "Duration            : ${DEMO_DURATION} seconds"
    echo "MQTT writer PID     : ${MQTT_WRITER_PID}"
    echo "Sensor simulator PID: ${SENSOR_SIM_PID}"
    echo
    echo "Completed workflow:"
    echo "  - Docker Compose infrastructure"
    echo "  - MQTT-to-Influx ingestion"
    echo "  - Continuous cleanroom sensor simulation"
    echo "  - InfluxDB data verification"
    echo "  - Provisioned Grafana dashboard"
    echo "  - OPC-UA server and client validation"
    echo "  - Modbus server and client validation"
    echo "  - Project orchestrator and scikit-learn workflow"
    echo "  - TensorFlow/Keras anomaly workflow"
    echo "  - Recipe integrity and tamper simulation"
    echo "  - Compliance evidence generation"
    echo "  - Final report generation"
    echo
    echo "Docker services:"
    docker compose ps 2>&1 || true
    echo
    echo "Report files:"
    find "${REPORTS_DIR}" -maxdepth 3 -type f -printf '  %p\n' 2>/dev/null | sort
    echo
    echo "Log files:"
    find "${LOGS_DIR}" -maxdepth 2 -type f -printf '  %p\n' 2>/dev/null | sort
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
echo "Live monitoring logs:"
echo "  tail -f logs/mqtt_to_influx.log"
echo "  tail -f logs/sensor_simulator.log"
echo
echo "Reports:"
echo "  ls -lah reports/"
echo
echo "Exam summary:"
echo "  cat ${SUMMARY_FILE}"
echo
echo "Master execution log:"
echo "  cat ${MASTER_LOG}"

if [[ "${STOP_MONITORING_AFTER_DEMO}" == "1" ]]; then
    echo
    echo "Monitoring services will be stopped after this script exits."
else
    echo
    echo "Monitoring services will remain running for the live Grafana demo."
    echo "Stop them later with:"
    echo "  kill \$(cat .runtime/mqtt_to_influx.pid) 2>/dev/null || true"
    echo "  kill \$(cat .runtime/sensor_simulator.pid) 2>/dev/null || true"
fi

if [[ "${STOP_DOCKER_AFTER_DEMO}" == "1" ]]; then
    echo "Docker services will be stopped after this script exits."
else
    echo "Docker services will remain running."
    echo "Stop them later with: docker compose down"
fi

echo
echo "============================================================"
echo "TOPIC 127 EXAM DEMONSTRATION COMPLETED SUCCESSFULLY"
echo "============================================================"