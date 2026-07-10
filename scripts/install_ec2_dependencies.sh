#!/usr/bin/env bash

# ================================================================
# Topic 127 / exam-new-v3
# EC2 Dependency Installation Script
#
# Improvements included:
#   1. Uses a supported fixed Python version
#   2. Handles Docker installation and docker-group permissions
#   3. Clearly explains logout/login requirement
#   4. Validates repository structure
#   5. Safely handles an existing virtual environment
#
# Default Python:
#   Python 3.11
#
# Usage:
#   chmod +x scripts/install_ec2_dependencies.sh
#   ./scripts/install_ec2_dependencies.sh
#
# Optional Python override:
#   PYTHON_BIN=python3.12 ./scripts/install_ec2_dependencies.sh
# ================================================================

set -Eeuo pipefail

# ----------------------------------------------------------------
# Configuration
# ----------------------------------------------------------------
PYTHON_BIN="${PYTHON_BIN:-python3.11}"
VENV_DIR="${VENV_DIR:-venv}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# ----------------------------------------------------------------
# Error handler
# ----------------------------------------------------------------
error_handler() {
    local exit_code=$?
    local line_number="${1:-unknown}"

    echo
    echo "============================================================"
    echo "ERROR: Installation failed"
    echo "Line: ${line_number}"
    echo "Exit code: ${exit_code}"
    echo "============================================================"
    echo
    echo "Review the error shown above and run the script again."

    exit "${exit_code}"
}

trap 'error_handler ${LINENO}' ERR

# ----------------------------------------------------------------
# Start
# ----------------------------------------------------------------
echo
echo "============================================================"
echo "Topic 127 — EC2 Dependency Installation"
echo "============================================================"
echo "Repository root : ${REPO_ROOT}"
echo "Python command   : ${PYTHON_BIN}"
echo "Virtual env      : ${REPO_ROOT}/${VENV_DIR}"
echo "Current user     : ${USER}"
echo "============================================================"

cd "${REPO_ROOT}"

# ----------------------------------------------------------------
# Repository validation
# ----------------------------------------------------------------
if [[ ! -f "requirements.txt" ]]; then
    echo
    echo "ERROR: requirements.txt was not found."
    echo
    echo "Expected location:"
    echo "  ${REPO_ROOT}/requirements.txt"
    echo
    echo "This script should be located at:"
    echo "  exam-new-v3/scripts/install_ec2_dependencies.sh"
    echo

    exit 1
fi

# ----------------------------------------------------------------
# Step 1: Update package index
# ----------------------------------------------------------------
echo
echo "[1/8] Updating Ubuntu package index..."

sudo apt-get update

# A full operating-system upgrade is intentionally not performed here.
# Run this separately when required:
#
#   sudo apt-get upgrade -y

# ----------------------------------------------------------------
# Step 2: Install common dependencies
# ----------------------------------------------------------------
echo
echo "[2/8] Installing common system dependencies..."

sudo DEBIAN_FRONTEND=noninteractive apt-get install -y \
    software-properties-common \
    ca-certificates \
    apt-transport-https \
    gnupg \
    lsb-release \
    git \
    curl \
    wget \
    unzip \
    jq \
    build-essential \
    pkg-config \
    docker.io \
    docker-compose-v2 \
    mosquitto-clients

# ----------------------------------------------------------------
# Step 3: Install selected Python version
# ----------------------------------------------------------------
echo
echo "[3/8] Checking selected Python version: ${PYTHON_BIN}"

if ! command -v "${PYTHON_BIN}" >/dev/null 2>&1; then
    echo
    echo "${PYTHON_BIN} is not currently installed."
    echo "Attempting installation from Ubuntu repositories..."

    if ! sudo DEBIAN_FRONTEND=noninteractive apt-get install -y \
        "${PYTHON_BIN}" \
        "${PYTHON_BIN}-venv" \
        "${PYTHON_BIN}-dev"; then

        echo
        echo "ERROR: ${PYTHON_BIN} could not be installed from the"
        echo "currently configured Ubuntu repositories."
        echo
        echo "Available Python versions may depend on the Ubuntu release."
        echo
        echo "Try a supported installed version, for example:"
        echo
        echo "  PYTHON_BIN=python3.12 ./scripts/install_ec2_dependencies.sh"
        echo

        exit 1
    fi
else
    echo "${PYTHON_BIN} is already installed."

    sudo DEBIAN_FRONTEND=noninteractive apt-get install -y \
        "${PYTHON_BIN}-venv" \
        "${PYTHON_BIN}-dev"
fi

echo
echo "Selected Python:"
"${PYTHON_BIN}" --version

# ----------------------------------------------------------------
# Step 4: Configure Docker
# ----------------------------------------------------------------
echo
echo "[4/8] Configuring Docker service..."

sudo systemctl enable docker
sudo systemctl start docker

if sudo systemctl is-active --quiet docker; then
    echo "Docker service is active."
else
    echo
    echo "ERROR: Docker service failed to start."
    echo

    sudo systemctl status docker --no-pager || true

    exit 1
fi

# Ensure docker group exists.
if ! getent group docker >/dev/null 2>&1; then
    echo "Creating docker group..."
    sudo groupadd docker
fi

# Add current user to docker group when required.
if id -nG "${USER}" | tr ' ' '\n' | grep -qx "docker"; then
    echo "User '${USER}' is already listed in the docker group."
else
    echo "Adding user '${USER}' to the docker group..."
    sudo usermod -aG docker "${USER}"
    echo "User '${USER}' was added to the docker group."
fi

# ----------------------------------------------------------------
# Step 5: Check existing virtual environment
# ----------------------------------------------------------------
echo
echo "[5/8] Checking the existing virtual environment..."

SELECTED_PYTHON_VERSION="$(
    "${PYTHON_BIN}" -c \
    'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")'
)"

if [[ -d "${VENV_DIR}" ]]; then
    if [[ -x "${VENV_DIR}/bin/python" ]]; then
        EXISTING_VENV_VERSION="$(
            "${VENV_DIR}/bin/python" -c \
            'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")'
        )"

        echo "Existing venv Python : ${EXISTING_VENV_VERSION}"
        echo "Selected Python      : ${SELECTED_PYTHON_VERSION}"

        if [[ "${EXISTING_VENV_VERSION}" != "${SELECTED_PYTHON_VERSION}" ]]; then
            BACKUP_NAME="${VENV_DIR}.backup.$(date +%Y%m%d_%H%M%S)"

            echo
            echo "Existing virtual environment uses another Python version."
            echo "Moving it to:"
            echo "  ${BACKUP_NAME}"

            mv "${VENV_DIR}" "${BACKUP_NAME}"
        else
            echo "Existing virtual environment uses the correct Python version."
        fi
    else
        BACKUP_NAME="${VENV_DIR}.invalid.$(date +%Y%m%d_%H%M%S)"

        echo
        echo "The existing '${VENV_DIR}' directory is not a valid venv."
        echo "Moving it to:"
        echo "  ${BACKUP_NAME}"

        mv "${VENV_DIR}" "${BACKUP_NAME}"
    fi
fi

# ----------------------------------------------------------------
# Step 6: Create virtual environment
# ----------------------------------------------------------------
echo
echo "[6/8] Creating or reusing the virtual environment..."

if [[ ! -d "${VENV_DIR}" ]]; then
    "${PYTHON_BIN}" -m venv "${VENV_DIR}"
    echo "Virtual environment created successfully."
else
    echo "Reusing the existing compatible virtual environment."
fi

# shellcheck disable=SC1091
source "${VENV_DIR}/bin/activate"

echo
echo "Virtual environment Python:"
python --version

echo "Virtual environment executable:"
python -c 'import sys; print(sys.executable)'

# ----------------------------------------------------------------
# Step 7: Install Python dependencies
# ----------------------------------------------------------------
echo
echo "[7/8] Installing Python dependencies..."

python -m pip install --upgrade pip setuptools wheel
python -m pip install -r requirements.txt

# ----------------------------------------------------------------
# Step 8: Verification
# ----------------------------------------------------------------
echo
echo "[8/8] Verifying the installation..."

python -m pip check

echo
echo "Python:"
python --version

echo
echo "Pip:"
python -m pip --version

echo
echo "Docker:"
docker --version

echo
echo "Docker Compose:"
docker compose version

echo
echo "Docker service:"
sudo systemctl is-active docker

# Test Docker through sudo because the new group may not yet be active
# in the current SSH session.
echo
echo "Testing Docker daemon through sudo..."

if sudo docker info >/dev/null 2>&1; then
    echo "Docker daemon is responding correctly."
else
    echo
    echo "ERROR: Docker daemon is installed but is not responding."
    echo "Check it using:"
    echo
    echo "  sudo systemctl status docker"
    echo

    exit 1
fi

# Check whether docker group is active in the current shell.
DOCKER_GROUP_ACTIVE=false

if id -nG | tr ' ' '\n' | grep -qx "docker"; then
    DOCKER_GROUP_ACTIVE=true
fi

# ----------------------------------------------------------------
# Final result
# ----------------------------------------------------------------
echo
echo "============================================================"
echo "Installation completed successfully"
echo "============================================================"
echo
echo "Repository:"
echo "  ${REPO_ROOT}"
echo
echo "Virtual environment:"
echo "  ${REPO_ROOT}/${VENV_DIR}"
echo
echo "Activate the virtual environment later with:"
echo
echo "  cd ${REPO_ROOT}"
echo "  source ${VENV_DIR}/bin/activate"
echo

if [[ "${DOCKER_GROUP_ACTIVE}" == "true" ]]; then
    echo "Docker group permission is active in this session."
    echo
    echo "Verify Docker without sudo:"
    echo
    echo "  docker ps"
else
    echo "============================================================"
    echo "IMPORTANT: Docker permission requires a new login session"
    echo "============================================================"
    echo
    echo "The user '${USER}' has been added to the docker group."
    echo
    echo "However, this permission is not active in the current"
    echo "SSH session."
    echo
    echo "Recommended method:"
    echo
    echo "  1. Exit the EC2 SSH session:"
    echo
    echo "     exit"
    echo
    echo "  2. Connect to the EC2 instance again."
    echo
    echo "  3. Verify Docker without sudo:"
    echo
    echo "     docker ps"
    echo
    echo "Temporary alternative for the current session:"
    echo
    echo "  newgrp docker"
    echo
    echo "Then run:"
    echo
    echo "  docker ps"
fi

echo
echo "After Docker permission is active, start the platform with:"
echo
echo "  docker compose up -d"
echo
echo "Check container status with:"
echo
echo "  docker compose ps"
echo
echo "============================================================"