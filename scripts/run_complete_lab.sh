#!/usr/bin/env bash

# ================================================================
# Topic 127 / exam-new-v3
# Complete Lab Execution Script
#
# Responsibilities:
#   1. Activate the Python virtual environment
#   2. Start Docker Compose infrastructure
#   3. Wait for Mosquitto, InfluxDB and Grafana
#   4. Start MQTT-to-Influx ingestion in the background
#   5. Start the cleanroom sensor simulator in the background
#   6. Verify that InfluxDB receives cleanroom data
#   7. Start local OPC-UA and Modbus servers when required
#   8. Run the main project orchestrator and validators
#   9. Run recipe-integrity and TensorFlow/Keras workflows
#  10. Preserve monitoring services for the live Grafana demo
#
# Usage:
#   chmod +x scripts/run_complete_lab.sh
#   ./scripts/run_complete_lab.sh
#
# Optional overrides:
#   STOP_MONITORING_AFTER_LAB=1 ./scripts/run_complete_lab.sh
#   MQTT_BROKER=localhost INFLUX_URL=http://localhost:8086 \
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
RUNTIME_DIR="${RUNTIME_DIR:-${REPO_ROOT}/.runtime}"

MQTT_BROKER="${MQTT_BROKER:-localhost}"
MQTT_PORT="${MQTT_PORT:-1883}"
MQTT_TOPIC="${MQTT_TOPIC:-topic127/cleanroom/sensors}"

INFLUX_URL="${INFLUX_URL:-http://localhost:8086}"
INFLUX_ORG="${INFLUX_ORG:-topic127}"
INFLUX_BUCKET="${INFLUX_BUCKET:-cleanroom}"
INFLUX_TOKEN="${INFLUX_TOKEN:-topic127-token}"

GRAFANA_HOST="${GRAFANA_HOST:-127.0.0.1}"
GRAFANA_PORT="${GRAFANA_PORT:-3000}"

OPCUA_HOST="${OPCUA_HOST:-127.0.0.1}"
OPCUA_PORT="${OPCUA_PORT:-4840}"

MODBUS_HOST="${MODBUS_HOST:-127.0.0.1}"
MODBUS_PORT="${MODBUS_PORT:-5020}"

SERVER_START_TIMEOUT="${SERVER_START_TIMEOUT:-30}"
DATA_START_TIMEOUT="${DATA_START_TIMEOUT:-45}"
STOP_MONITORING_AFTER_LAB="${STOP_MONITORING_AFTER_LAB:-0}"

MQTT_WRITER_PID_FILE="${RUNTIME_DIR}/mqtt_to_influx.pid"
SENSOR_SIM_PID_FILE="${RUNTIME_DIR}/sensor_simulator.pid"

OPCUA_PID=""
MODBUS_PID=""
MQTT_WRITER_STARTED_BY_SCRIPT=false
SENSOR_SIM_STARTED_BY_SCRIPT=false

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

success() {
    echo "SUCCESS: $1"
}

# ----------------------------------------------------------------
# Error handler
# ----------------------------------------------------------------
error_handler() {
    local exit_code=$?
    local line_number="${1:-unknown}"
    local command_name="${2:-unknown}"

    echo
    echo "============================================================"
    echo "ERROR: Complete lab execution failed"
    echo "Line      : ${line_number}"
    echo "Exit code : ${exit_code}"
    echo "Command   : ${command_name}"
    echo "============================================================"
    echo
    echo "Review the logs directory:"
    echo "  ${LOGS_DIR}"

    exit "${exit_code}"
}

trap 'error_handler "${LINENO}" "${BASH_COMMAND}"' ERR

# ----------------------------------------------------------------
# Process helpers
# ----------------------------------------------------------------
pid_is_running() {
    local pid="$1"
    [[ -n "${pid}" ]] && kill -0 "${pid}" 2>/dev/null
}

read_pid_file() {
    local pid_file="$1"
    if [[ -f "${pid_file}" ]]; then
        tr -d '[:space:]' < "${pid_file}"
    fi
}

stop_pid_file_process() {
    local service_name="$1"
    local pid_file="$2"
    local pid=""

    pid="$(read_pid_file "${pid_file}")"

    if pid_is_running "${pid}"; then
        echo "Stopping ${service_name} process: ${pid}"
        kill "${pid}" 2>/dev/null || true
        wait "${pid}" 2>/dev/null || true
    fi

    rm -f "${pid_file}"
}

# ----------------------------------------------------------------
# Cleanup handler
# ----------------------------------------------------------------
cleanup() {
    local original_exit_code=$?

    echo
    echo "Cleaning up locally started protocol services..."

    if pid_is_running "${OPCUA_PID}"; then
        echo "Stopping OPC-UA server process: ${OPCUA_PID}"
        kill "${OPCUA_PID}" 2>/dev/null || true
        wait "${OPCUA_PID}" 2>/dev/null || true
    fi

    if pid_is_running "${MODBUS_PID}"; then
        echo "Stopping Modbus server process: ${MODBUS_PID}"
        kill "${MODBUS_PID}" 2>/dev/null || true
        wait "${MODBUS_PID}" 2>/dev/null || true
    fi

    if [[ "${STOP_MONITORING_AFTER_LAB}" == "1" ]]; then
        echo "Stopping monitoring services by configuration..."
        stop_pid_file_process "MQTT-to-Influx writer" "${MQTT_WRITER_PID_FILE}"
        stop_pid_file_process "sensor simulator" "${SENSOR_SIM_PID_FILE}"
    else
        echo "Monitoring services will remain running for Grafana."
    fi

    exit "${original_exit_code}"
}

trap cleanup EXIT

# ----------------------------------------------------------------
# TCP port helpers
# ----------------------------------------------------------------
port_is_open() {
    local host="$1"
    local port="$2"

    timeout 1 bash -c "echo > /dev/tcp/${host}/${port}" >/dev/null 2>&1
}

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
# Docker helpers
# ----------------------------------------------------------------
docker_command_available() {
    command -v docker >/dev/null 2>&1
}

docker_daemon_accessible() {
    docker_command_available && docker info >/dev/null 2>&1
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
# Start persistent Python service without duplicates
# ----------------------------------------------------------------
start_persistent_python_service() {
    local service_name="$1"
    local script_path="$2"
    local log_path="$3"
    local pid_file="$4"
    shift 4

    local existing_pid=""
    local new_pid=""

    if [[ ! -f "${script_path}" ]]; then
        echo "ERROR: ${service_name} script was not found:"
        echo "  ${script_path}"
        return 1
    fi

    existing_pid="$(read_pid_file "${pid_file}")"

    if pid_is_running "${existing_pid}"; then
        echo "${service_name} is already running with PID ${existing_pid}."
        return 0
    fi

    rm -f "${pid_file}"

    # Also avoid duplicates created manually outside this script.
    if pgrep -f "python(3)? .*${script_path}" >/dev/null 2>&1; then
        existing_pid="$(pgrep -f "python(3)? .*${script_path}" | head -n 1)"
        echo "${service_name} is already running with PID ${existing_pid}."
        printf '%s\n' "${existing_pid}" > "${pid_file}"
        return 0
    fi

    echo "Starting ${service_name}:"
    echo "  ${script_path}"
    echo "Log:"
    echo "  ${log_path}"

    env "$@" python -u "${script_path}" > "${log_path}" 2>&1 &
    new_pid=$!
    printf '%s\n' "${new_pid}" > "${pid_file}"

    sleep 2

    if ! pid_is_running "${new_pid}"; then
        echo "ERROR: ${service_name} exited during startup."
        echo "Review:"
        echo "  ${log_path}"
        tail -n 50 "${log_path}" 2>/dev/null || true
        return 1
    fi

    echo "${service_name} started with PID ${new_pid}."
    return 0
}

# ----------------------------------------------------------------
# Verify InfluxDB received data
# ----------------------------------------------------------------
influx_has_cleanroom_data() {
    local query_output

    if ! query_output="$(
        docker exec topic127-influxdb influx query \
            "from(bucket: \"${INFLUX_BUCKET}\")
              |> range(start: -15m)
              |> filter(fn: (r) => r._measurement == \"cleanroom_monitoring\")
              |> limit(n: 1)" \
            --org "${INFLUX_ORG}" \
            --token "${INFLUX_TOKEN}" \
            2>/dev/null
    )"; then
        return 1
    fi

    grep -Fq "cleanroom_monitoring" <<<"${query_output}"
}
wait_for_influx_data() {
    local elapsed=0

    echo "Waiting for cleanroom data in InfluxDB..."

    while (( elapsed < DATA_START_TIMEOUT )); do
        if influx_has_cleanroom_data; then
            echo "Cleanroom data is present in InfluxDB."
            return 0
        fi

        sleep 2
        ((elapsed += 2))
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
        echo "Expected file: ${script_path}"
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
        echo "The complete lab will continue. Review: ${log_path}"
    fi

    return 0
}

# ----------------------------------------------------------------
# Repository setup
# ----------------------------------------------------------------
cd "${REPO_ROOT}"
mkdir -p "${REPORTS_DIR}" "${LOGS_DIR}" "${RUNTIME_DIR}"

section "Topic 127 — Complete Lab Execution"

echo "Repository root   : ${REPO_ROOT}"
echo "Reports directory : ${REPORTS_DIR}"
echo "Logs directory    : ${LOGS_DIR}"
echo "MQTT endpoint     : ${MQTT_BROKER}:${MQTT_PORT}"
echo "InfluxDB          : ${INFLUX_URL}"
echo "Influx org/bucket : ${INFLUX_ORG}/${INFLUX_BUCKET}"
echo "OPC-UA endpoint   : ${OPCUA_HOST}:${OPCUA_PORT}"
echo "Modbus endpoint   : ${MODBUS_HOST}:${MODBUS_PORT}"

# ----------------------------------------------------------------
# Step 1: Activate virtual environment
# ----------------------------------------------------------------
section "[1/11] Activating Python virtual environment"

if [[ ! -f "${VENV_DIR}/bin/activate" ]]; then
    echo "ERROR: Python virtual environment was not found: ${VENV_DIR}"
    echo "Run: ./scripts/install_ec2_dependencies.sh"
    exit 1
fi

# shellcheck disable=SC1091
source "${VENV_DIR}/bin/activate"

python -c 'import sys; print("Python executable:", sys.executable)'
python --version

# ----------------------------------------------------------------
# Step 2: Start Docker Compose infrastructure
# ----------------------------------------------------------------
section "[2/11] Starting Docker Compose infrastructure"

if ! docker_command_available; then
    echo "ERROR: Docker command is unavailable."
    exit 1
elif ! docker_compose_available; then
    echo "ERROR: Docker Compose or docker-compose.yml is unavailable."
    exit 1
elif ! docker_daemon_accessible; then
    echo "ERROR: Docker daemon is unavailable or permission is denied."
    echo "Reconnect to EC2 after docker-group setup, then run: docker ps"
    exit 1
fi

docker compose config >/dev/null
docker compose up -d
docker compose ps

wait_for_port "Mosquitto" "127.0.0.1" "${MQTT_PORT}" "${SERVER_START_TIMEOUT}" || {
    echo "ERROR: Mosquitto did not become ready."
    exit 1
}

wait_for_port "InfluxDB" "127.0.0.1" "8086" "${SERVER_START_TIMEOUT}" || {
    echo "ERROR: InfluxDB did not become ready."
    exit 1
}

wait_for_port "Grafana" "${GRAFANA_HOST}" "${GRAFANA_PORT}" "${SERVER_START_TIMEOUT}" || {
    warning "Grafana did not become ready within ${SERVER_START_TIMEOUT} seconds."
}

# ----------------------------------------------------------------
# Step 3: Start MQTT-to-Influx writer
# ----------------------------------------------------------------
section "[3/11] Starting MQTT-to-Influx ingestion"

start_persistent_python_service \
    "MQTT-to-Influx writer" \
    "${REPO_ROOT}/src/mqtt_to_influx.py" \
    "${LOGS_DIR}/mqtt_to_influx.log" \
    "${MQTT_WRITER_PID_FILE}" \
    MQTT_BROKER="${MQTT_BROKER}" \
    MQTT_PORT="${MQTT_PORT}" \
    MQTT_TOPIC="${MQTT_TOPIC}" \
    INFLUX_URL="${INFLUX_URL}" \
    INFLUX_ORG="${INFLUX_ORG}" \
    INFLUX_BUCKET="${INFLUX_BUCKET}" \
    INFLUX_TOKEN="${INFLUX_TOKEN}"

MQTT_WRITER_STARTED_BY_SCRIPT=true

# ----------------------------------------------------------------
# Step 4: Start sensor simulator
# ----------------------------------------------------------------
section "[4/11] Starting cleanroom sensor simulator"

start_persistent_python_service \
    "Cleanroom sensor simulator" \
    "${REPO_ROOT}/src/sensor_simulator.py" \
    "${LOGS_DIR}/sensor_simulator.log" \
    "${SENSOR_SIM_PID_FILE}" \
    MQTT_BROKER="${MQTT_BROKER}" \
    MQTT_PORT="${MQTT_PORT}" \
    MQTT_TOPIC="${MQTT_TOPIC}"

SENSOR_SIM_STARTED_BY_SCRIPT=true

# ----------------------------------------------------------------
# Step 5: Verify monitoring pipeline
# ----------------------------------------------------------------
section "[5/11] Verifying MQTT-to-Influx monitoring pipeline"

if ! wait_for_influx_data; then
    echo "ERROR: No cleanroom data appeared in InfluxDB within ${DATA_START_TIMEOUT} seconds."
    echo
    echo "Writer log: ${LOGS_DIR}/mqtt_to_influx.log"
    echo "Simulator log: ${LOGS_DIR}/sensor_simulator.log"
    echo
    tail -n 50 "${LOGS_DIR}/mqtt_to_influx.log" 2>/dev/null || true
    tail -n 50 "${LOGS_DIR}/sensor_simulator.log" 2>/dev/null || true
    exit 1
fi

success "Live cleanroom monitoring pipeline is working."

# ----------------------------------------------------------------
# Step 6: Start OPC-UA server
# ----------------------------------------------------------------
section "[6/11] Starting OPC-UA server"

if port_is_open "${OPCUA_HOST}" "${OPCUA_PORT}"; then
    echo "OPC-UA server is already reachable at ${OPCUA_HOST}:${OPCUA_PORT}."
else
    OPCUA_SERVER_SCRIPT="$(find_python_script "src/opcua_server.py" "src/opcua_server_simulator.py" "src/opcua_simulator.py" || true)"

    if [[ -n "${OPCUA_SERVER_SCRIPT}" ]]; then
        python "${OPCUA_SERVER_SCRIPT}" > "${LOGS_DIR}/opcua_server.log" 2>&1 &
        OPCUA_PID=$!
        echo "OPC-UA server process ID: ${OPCUA_PID}"
    else
        warning "No OPC-UA server script was found."
    fi
fi

if ! wait_for_port "OPC-UA server" "${OPCUA_HOST}" "${OPCUA_PORT}" "${SERVER_START_TIMEOUT}"; then
    warning "OPC-UA server did not become ready. Validator will still execute."
fi

# ----------------------------------------------------------------
# Step 7: Start Modbus server
# ----------------------------------------------------------------
section "[7/11] Starting Modbus server"

if port_is_open "${MODBUS_HOST}" "${MODBUS_PORT}"; then
    echo "Modbus server is already reachable at ${MODBUS_HOST}:${MODBUS_PORT}."
else
    MODBUS_SERVER_SCRIPT="$(find_python_script "src/modbus_server.py" "src/modbus_server_simulator.py" "src/modbus_simulator.py" || true)"

    if [[ -n "${MODBUS_SERVER_SCRIPT}" ]]; then
        python "${MODBUS_SERVER_SCRIPT}" > "${LOGS_DIR}/modbus_server.log" 2>&1 &
        MODBUS_PID=$!
        echo "Modbus server process ID: ${MODBUS_PID}"
    else
        warning "No Modbus server script was found."
    fi
fi

if ! wait_for_port "Modbus server" "${MODBUS_HOST}" "${MODBUS_PORT}" "${SERVER_START_TIMEOUT}"; then
    warning "Modbus server did not become ready. Validator will still execute."
fi

# ----------------------------------------------------------------
# Step 8: Run project orchestrator
# ----------------------------------------------------------------
section "[8/11] Running main project orchestrator"

ORCHESTRATOR_SCRIPT="${REPO_ROOT}/src/project_orchestrator.py"

if [[ ! -f "${ORCHESTRATOR_SCRIPT}" ]]; then
    echo "ERROR: Main orchestrator was not found: ${ORCHESTRATOR_SCRIPT}"
    exit 1
fi

set +e
python "${ORCHESTRATOR_SCRIPT}" 2>&1 | tee "${LOGS_DIR}/project_orchestrator.log"
ORCHESTRATOR_EXIT_CODE=${PIPESTATUS[0]}
set -e

if [[ "${ORCHESTRATOR_EXIT_CODE}" -ne 0 ]]; then
    echo "ERROR: Main project orchestrator failed with exit code ${ORCHESTRATOR_EXIT_CODE}."
    exit "${ORCHESTRATOR_EXIT_CODE}"
fi

# ----------------------------------------------------------------
# Step 9: Run industrial and recipe validators
# ----------------------------------------------------------------
section "[9/11] Running industrial protocol and recipe validators"

run_optional_python_component \
    "OPC-UA client validator" \
    "${REPO_ROOT}/src/opcua_client_validator.py" \
    "${LOGS_DIR}/opcua_client_validator.log"

run_optional_python_component \
    "Modbus client validator" \
    "${REPO_ROOT}/src/modbus_client_validator.py" \
    "${LOGS_DIR}/modbus_client_validator.log"

run_optional_python_component \
    "Recipe integrity check" \
    "${REPO_ROOT}/src/recipe_integrity_check.py" \
    "${LOGS_DIR}/recipe_integrity_check.log"

# ----------------------------------------------------------------
# Step 10: Run TensorFlow/Keras engine
# ----------------------------------------------------------------
section "[10/11] Running TensorFlow/Keras anomaly engine"

TENSORFLOW_SCRIPT="${REPO_ROOT}/scripts/run_tensorflow_ml.sh"

if [[ -f "${TENSORFLOW_SCRIPT}" ]]; then
    set +e
    bash "${TENSORFLOW_SCRIPT}" 2>&1 | tee "${LOGS_DIR}/tensorflow_ml.log"
    TENSORFLOW_EXIT_CODE=${PIPESTATUS[0]}
    set -e

    if [[ "${TENSORFLOW_EXIT_CODE}" -eq 0 ]]; then
        echo "TensorFlow/Keras anomaly engine completed successfully."
    else
        warning "TensorFlow/Keras engine returned exit code ${TENSORFLOW_EXIT_CODE}."
    fi
else
    warning "TensorFlow launcher script was not found: ${TENSORFLOW_SCRIPT}"
fi

# ----------------------------------------------------------------
# Step 11: Final summary
# ----------------------------------------------------------------
section "[11/11] Complete Lab Execution Finished"

MQTT_WRITER_PID="$(read_pid_file "${MQTT_WRITER_PID_FILE}")"
SENSOR_SIM_PID="$(read_pid_file "${SENSOR_SIM_PID_FILE}")"

echo "Monitoring services:"
echo "  MQTT-to-Influx PID : ${MQTT_WRITER_PID:-unknown}"
echo "  Sensor simulator PID: ${SENSOR_SIM_PID:-unknown}"
echo
echo "Grafana dashboard:"
echo "  http://EC2-PUBLIC-IP:3000"
echo
echo "Generated report files:"
find "${REPORTS_DIR}" -maxdepth 2 -type f -printf '  %p\n' 2>/dev/null | sort || true

echo
echo "Generated log files:"
find "${LOGS_DIR}" -maxdepth 1 -type f -printf '  %p\n' 2>/dev/null | sort || true

echo
echo "Useful commands:"
echo "  docker compose ps"
echo "  tail -f logs/mqtt_to_influx.log"
echo "  tail -f logs/sensor_simulator.log"
echo "  docker exec topic127-influxdb influx query 'from(bucket: \"cleanroom\") |> range(start: -5m) |> last()' --org topic127 --token topic127-token"
echo
echo "To stop monitoring services later:"
echo "  kill \$(cat .runtime/mqtt_to_influx.pid) 2>/dev/null || true"
echo "  kill \$(cat .runtime/sensor_simulator.pid) 2>/dev/null || true"
echo
echo "============================================================"
echo "Topic 127 complete lab execution finished successfully."
echo "============================================================"
