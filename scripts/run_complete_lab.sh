#!/usr/bin/env bash

# ================================================================
# Topic 127 / exam-new-v3
# Complete Lab Execution Script
#
# Responsibilities:
#   1. Activate Python virtual environment
#   2. Create reports and logs directories
#   3. Start Docker Compose infrastructure when available
#   4. Start local OPC-UA server when required
#   5. Start local Modbus server when required
#   6. Wait for industrial protocol ports
#   7. Run the main project orchestrator
#   8. Run OPC-UA, Modbus and recipe validators
#   9. Run TensorFlow/Keras anomaly engine
#  10. Stop locally started background services safely
#
# Usage:
#   chmod +x scripts/run_complete_lab.sh
#   ./scripts/run_complete_lab.sh
#
# Optional overrides:
#   OPCUA_PORT=4840 MODBUS_PORT=1502 \
#   ./scripts/run_complete_lab.sh
# ================================================================

set -Eeuo pipefail

# ----------------------------------------------------------------
# Configuration
# ----------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

VENV_DIR="${VENV_DIR:-${REPO_ROOT}/venv}"

REPORTS_DIR="${REPORTS_DIR:-${REPO_ROOT}/reports}"
LOGS_DIR="${LOGS_DIR:-${REPO_ROOT}/logs}"

OPCUA_HOST="${OPCUA_HOST:-127.0.0.1}"
OPCUA_PORT="${OPCUA_PORT:-4840}"

MODBUS_HOST="${MODBUS_HOST:-127.0.0.1}"
MODBUS_PORT="${MODBUS_PORT:-5020}"

SERVER_START_TIMEOUT="${SERVER_START_TIMEOUT:-30}"

OPCUA_PID=""
MODBUS_PID=""

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
# Error handler
# ----------------------------------------------------------------
error_handler() {
    local exit_code=$?
    local line_number="${1:-unknown}"

    echo
    echo "============================================================"
    echo "ERROR: Complete lab execution failed"
    echo "Line      : ${line_number}"
    echo "Exit code : ${exit_code}"
    echo "============================================================"
    echo
    echo "Review the logs directory:"
    echo "  ${LOGS_DIR}"

    exit "${exit_code}"
}

trap 'error_handler ${LINENO}' ERR

# ----------------------------------------------------------------
# Cleanup handler
# ----------------------------------------------------------------
cleanup() {
    local original_exit_code=$?

    echo
    echo "Cleaning up locally started background services..."

    if [[ -n "${OPCUA_PID}" ]] &&
       kill -0 "${OPCUA_PID}" 2>/dev/null; then

        echo "Stopping OPC-UA server process: ${OPCUA_PID}"
        kill "${OPCUA_PID}" 2>/dev/null || true
        wait "${OPCUA_PID}" 2>/dev/null || true
    fi

    if [[ -n "${MODBUS_PID}" ]] &&
       kill -0 "${MODBUS_PID}" 2>/dev/null; then

        echo "Stopping Modbus server process: ${MODBUS_PID}"
        kill "${MODBUS_PID}" 2>/dev/null || true
        wait "${MODBUS_PID}" 2>/dev/null || true
    fi

    if [[ -z "${OPCUA_PID}" ]] && [[ -z "${MODBUS_PID}" ]]; then
        echo "No local background servers require cleanup."
    fi

    exit "${original_exit_code}"
}

trap cleanup EXIT

# ----------------------------------------------------------------
# TCP port check
# ----------------------------------------------------------------
port_is_open() {
    local host="$1"
    local port="$2"

    timeout 1 bash -c \
        "echo > /dev/tcp/${host}/${port}" \
        >/dev/null 2>&1
}

# ----------------------------------------------------------------
# Wait for service port
# ----------------------------------------------------------------
wait_for_port() {
    local service_name="$1"
    local host="$2"
    local port="$3"
    local timeout_seconds="$4"

    local elapsed=0

    echo "Waiting for ${service_name} at ${host}:${port}..."

    while (( elapsed < timeout_seconds )); do
        if port_is_open "${host}" "${port}"; then
            echo "${service_name} is ready."
            return 0
        fi

        sleep 1
        ((elapsed += 1))
    done

    return 1
}

# ----------------------------------------------------------------
# Docker checks
# ----------------------------------------------------------------
docker_command_available() {
    command -v docker >/dev/null 2>&1
}

docker_daemon_accessible() {
    docker_command_available &&
    docker info >/dev/null 2>&1
}

docker_compose_available() {
    docker_command_available &&
    docker compose version >/dev/null 2>&1 &&
    [[ -f "${REPO_ROOT}/docker-compose.yml" ]]
}

# ----------------------------------------------------------------
# Find first matching Python file
# ----------------------------------------------------------------
find_python_script() {
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
# Run optional Python component
# ----------------------------------------------------------------
run_optional_python_component() {
    local component_name="$1"
    local script_path="$2"
    local log_path="$3"

    echo
    echo "Running ${component_name}..."

    if [[ ! -f "${script_path}" ]]; then
        warning "${component_name} file was not found."

        echo "Expected file:"
        echo "  ${script_path}"
        echo
        echo "Skipping this optional component."

        return 0
    fi

    set +e

    python "${script_path}" 2>&1 | tee "${log_path}"
    local component_exit_code=${PIPESTATUS[0]}

    set -e

    if [[ "${component_exit_code}" -eq 0 ]]; then
        echo "${component_name} completed successfully."
    else
        warning "${component_name} returned exit code ${component_exit_code}."

        echo "The complete lab will continue."
        echo "Review its log:"
        echo "  ${log_path}"
    fi

    return 0
}

# ----------------------------------------------------------------
# Repository setup
# ----------------------------------------------------------------
cd "${REPO_ROOT}"

mkdir -p "${REPORTS_DIR}" "${LOGS_DIR}"

section "Topic 127 — Complete Lab Execution"

echo "Repository root   : ${REPO_ROOT}"
echo "Reports directory : ${REPORTS_DIR}"
echo "Logs directory    : ${LOGS_DIR}"
echo "OPC-UA endpoint   : ${OPCUA_HOST}:${OPCUA_PORT}"
echo "Modbus endpoint   : ${MODBUS_HOST}:${MODBUS_PORT}"

# ----------------------------------------------------------------
# Step 1: Activate virtual environment
# ----------------------------------------------------------------
section "[1/9] Activating Python virtual environment"

if [[ ! -f "${VENV_DIR}/bin/activate" ]]; then
    echo "ERROR: Python virtual environment was not found."
    echo
    echo "Expected location:"
    echo "  ${VENV_DIR}"
    echo
    echo "Run the installation script first:"
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
# Step 2: Start Docker Compose infrastructure
# ----------------------------------------------------------------
section "[2/9] Starting Docker Compose infrastructure"

if ! docker_command_available; then
    warning "Docker command is not installed or not available in PATH."

    echo "This is normal when only performing a syntax check on"
    echo "Windows Git Bash."
    echo
    echo "On Ubuntu EC2, run:"
    echo "  ./scripts/install_ec2_dependencies.sh"
    echo
    echo "Continuing with local Python protocol servers."

elif ! docker_compose_available; then
    warning "Docker Compose is unavailable or docker-compose.yml is missing."

    echo "Continuing with local Python protocol servers."

elif ! docker_daemon_accessible; then
    warning "Docker is installed, but the current user cannot access the daemon."

    echo
    echo "On EC2, log out and reconnect, then verify:"
    echo "  docker ps"
    echo
    echo "Temporary current-session alternative:"
    echo "  newgrp docker"
    echo
    echo "Continuing with local Python protocol servers."

else
    echo "Starting Docker Compose services..."

    docker compose up -d

    echo
    echo "Docker Compose service status:"
    docker compose ps
fi

# ----------------------------------------------------------------
# Step 3: Start OPC-UA server
# ----------------------------------------------------------------
section "[3/9] Starting OPC-UA server"

if port_is_open "${OPCUA_HOST}" "${OPCUA_PORT}"; then
    echo "OPC-UA server is already reachable at:"
    echo "  ${OPCUA_HOST}:${OPCUA_PORT}"
else
    OPCUA_SERVER_SCRIPT="$(
        find_python_script \
            "src/opcua_server.py" \
            "src/opcua_server_simulator.py" \
            "src/opcua_simulator.py" ||
        true
    )"

    if [[ -n "${OPCUA_SERVER_SCRIPT}" ]]; then
        echo "Starting local OPC-UA server:"
        echo "  ${OPCUA_SERVER_SCRIPT}"

        python "${OPCUA_SERVER_SCRIPT}" \
            > "${LOGS_DIR}/opcua_server.log" 2>&1 &

        OPCUA_PID=$!

        echo "OPC-UA server process ID:"
        echo "  ${OPCUA_PID}"
    else
        warning "No OPC-UA server script was found."

        echo "Checked:"
        echo "  src/opcua_server.py"
        echo "  src/opcua_server_simulator.py"
        echo "  src/opcua_simulator.py"
    fi
fi

if ! wait_for_port \
    "OPC-UA server" \
    "${OPCUA_HOST}" \
    "${OPCUA_PORT}" \
    "${SERVER_START_TIMEOUT}"; then

    echo
    echo "WARNING:"
    echo "OPC-UA server did not become ready within"
    echo "${SERVER_START_TIMEOUT} seconds."
    echo
    echo "The OPC-UA validator will still execute so that"
    echo "diagnostic output can be recorded."
    echo
    echo "Review the server log:"
    echo "  ${LOGS_DIR}/opcua_server.log"
fi

# ----------------------------------------------------------------
# Step 4: Start Modbus server
# ----------------------------------------------------------------
section "[4/9] Starting Modbus server"

if port_is_open "${MODBUS_HOST}" "${MODBUS_PORT}"; then
    echo "Modbus server is already reachable at:"
    echo "  ${MODBUS_HOST}:${MODBUS_PORT}"
else
    MODBUS_SERVER_SCRIPT="$(
        find_python_script \
            "src/modbus_server.py" \
            "src/modbus_server_simulator.py" \
            "src/modbus_simulator.py" ||
        true
    )"

    if [[ -n "${MODBUS_SERVER_SCRIPT}" ]]; then
        echo "Starting local Modbus server:"
        echo "  ${MODBUS_SERVER_SCRIPT}"

        python "${MODBUS_SERVER_SCRIPT}" \
            > "${LOGS_DIR}/modbus_server.log" 2>&1 &

        MODBUS_PID=$!

        echo "Modbus server process ID:"
        echo "  ${MODBUS_PID}"
    else
        warning "No Modbus server script was found."

        echo "Checked:"
        echo "  src/modbus_server.py"
        echo "  src/modbus_server_simulator.py"
        echo "  src/modbus_simulator.py"
    fi
fi

if ! wait_for_port \
    "Modbus server" \
    "${MODBUS_HOST}" \
    "${MODBUS_PORT}" \
    "${SERVER_START_TIMEOUT}"; then

    echo
    echo "WARNING:"
    echo "Modbus server did not become ready within"
    echo "${SERVER_START_TIMEOUT} seconds."
    echo
    echo "The Modbus validator will still execute so that"
    echo "diagnostic output can be recorded."
    echo
    echo "Review the server log:"
    echo "  ${LOGS_DIR}/modbus_server.log"
fi

# ----------------------------------------------------------------
# Step 5: Run project orchestrator
# ----------------------------------------------------------------
section "[5/9] Running main project orchestrator"

ORCHESTRATOR_SCRIPT="${REPO_ROOT}/src/project_orchestrator.py"

if [[ ! -f "${ORCHESTRATOR_SCRIPT}" ]]; then
    echo "ERROR: Main orchestrator was not found."
    echo
    echo "Expected file:"
    echo "  ${ORCHESTRATOR_SCRIPT}"

    exit 1
fi

set +e

python "${ORCHESTRATOR_SCRIPT}" \
    2>&1 | tee "${LOGS_DIR}/project_orchestrator.log"

ORCHESTRATOR_EXIT_CODE=${PIPESTATUS[0]}

set -e

if [[ "${ORCHESTRATOR_EXIT_CODE}" -ne 0 ]]; then
    echo
    echo "ERROR: Main project orchestrator failed."
    echo "Exit code:"
    echo "  ${ORCHESTRATOR_EXIT_CODE}"
    echo
    echo "Review:"
    echo "  ${LOGS_DIR}/project_orchestrator.log"

    exit "${ORCHESTRATOR_EXIT_CODE}"
fi

echo "Main project orchestrator completed successfully."

# ----------------------------------------------------------------
# Step 6: Run OPC-UA validator
# ----------------------------------------------------------------
section "[6/9] Running OPC-UA validation"

run_optional_python_component \
    "OPC-UA client validator" \
    "${REPO_ROOT}/src/opcua_client_validator.py" \
    "${LOGS_DIR}/opcua_client_validator.log"

# ----------------------------------------------------------------
# Step 7: Run Modbus validator
# ----------------------------------------------------------------
section "[7/9] Running Modbus validation"

run_optional_python_component \
    "Modbus client validator" \
    "${REPO_ROOT}/src/modbus_client_validator.py" \
    "${LOGS_DIR}/modbus_client_validator.log"

# ----------------------------------------------------------------
# Step 8: Run recipe integrity check
# ----------------------------------------------------------------
section "[8/9] Running recipe integrity validation"

run_optional_python_component \
    "Recipe integrity check" \
    "${REPO_ROOT}/src/recipe_integrity_check.py" \
    "${LOGS_DIR}/recipe_integrity_check.log"

# ----------------------------------------------------------------
# Step 9: Run TensorFlow/Keras engine
# ----------------------------------------------------------------
section "[9/9] Running TensorFlow/Keras anomaly engine"

TENSORFLOW_SCRIPT="${REPO_ROOT}/scripts/run_tensorflow_ml.sh"

if [[ -f "${TENSORFLOW_SCRIPT}" ]]; then
    set +e

    bash "${TENSORFLOW_SCRIPT}" \
        2>&1 | tee "${LOGS_DIR}/tensorflow_ml.log"

    TENSORFLOW_EXIT_CODE=${PIPESTATUS[0]}

    set -e

    if [[ "${TENSORFLOW_EXIT_CODE}" -eq 0 ]]; then
        echo "TensorFlow/Keras anomaly engine completed successfully."
    else
        warning "TensorFlow/Keras engine returned exit code ${TENSORFLOW_EXIT_CODE}."

        echo "The core lab and protocol validators have already completed."
        echo
        echo "Review:"
        echo "  ${LOGS_DIR}/tensorflow_ml.log"
    fi
else
    warning "TensorFlow launcher script was not found."

    echo "Expected file:"
    echo "  ${TENSORFLOW_SCRIPT}"
fi

# ----------------------------------------------------------------
# Final summary
# ----------------------------------------------------------------
section "Complete Lab Execution Finished"

echo "Generated report files:"

if find "${REPORTS_DIR}" -maxdepth 2 -type f -print -quit \
    2>/dev/null | grep -q .; then

    find "${REPORTS_DIR}" \
        -maxdepth 2 \
        -type f \
        -printf '  %p\n' \
        2>/dev/null | sort
else
    echo "  No report files found."
fi

echo
echo "Generated log files:"

if find "${LOGS_DIR}" -maxdepth 1 -type f -print -quit \
    2>/dev/null | grep -q .; then

    find "${LOGS_DIR}" \
        -maxdepth 1 \
        -type f \
        -printf '  %p\n' \
        2>/dev/null | sort
else
    echo "  No log files found."
fi

echo
echo "Recommended verification commands:"
echo
echo "  ls -lah reports/"
echo "  ls -lah logs/"
echo
echo "  cat logs/opcua_client_validator.log"
echo "  cat logs/modbus_client_validator.log"
echo "  cat logs/recipe_integrity_check.log"

if docker_daemon_accessible && docker_compose_available; then
    echo
    echo "  docker compose ps"
fi

echo
echo "============================================================"
echo "Topic 127 complete lab execution finished."
echo "============================================================"
