
#!/usr/bin/env bash

# ================================================================
# Topic 127 / exam-new-v3
# EC2 Dependency Installation Script
#
# Purpose:
#   Install system packages, Python 3.12, Docker, Docker Compose,
#   Mosquitto clients, create a Python 3.12 virtual environment,
#   install requirements.txt, and verify the installation.
#
# Recommended operating system:
#   Ubuntu Server 24.04 LTS x86_64
#
# Required project Python:
#   Python 3.12
#
# Usage:
#   chmod +x scripts/install_ec2_dependencies.sh
#   ./scripts/install_ec2_dependencies.sh
#
# Optional overrides:
#   PYTHON_BIN=python3.12 ./scripts/install_ec2_dependencies.sh
#   VENV_DIR=myenv ./scripts/install_ec2_dependencies.sh
#
# Important:
#   This script intentionally does not perform a full OS upgrade.
# ================================================================

set -Eeuo pipefail

# ----------------------------------------------------------------
# Configuration
# ----------------------------------------------------------------

REQUIRED_PYTHON_MAJOR_MINOR="3.12"
PYTHON_BIN="${PYTHON_BIN:-python3.12}"
VENV_DIR="${VENV_DIR:-venv}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
VENV_PATH="${REPO_ROOT}/${VENV_DIR}"

CURRENT_USER="${SUDO_USER:-${USER:-$(id -un)}}"

# These variables are populated after reading /etc/os-release.
OS_ID="unknown"
OS_VERSION_ID="unknown"
OS_CODENAME="unknown"
OS_PRETTY_NAME="unknown"

# ----------------------------------------------------------------
# Output helpers
# ----------------------------------------------------------------

print_separator() {
    echo "============================================================"
}

print_step() {
    local step_number="$1"
    local step_title="$2"

    echo
    echo "[${step_number}/8] ${step_title}"
}

print_error() {
    echo
    print_separator
    echo "ERROR: $*"
    print_separator
    echo
}

print_warning() {
    echo
    echo "WARNING: $*"
    echo
}

# ----------------------------------------------------------------
# Error handler
# ----------------------------------------------------------------

error_handler() {
    local exit_code=$?
    local line_number="${1:-unknown}"
    local command_name="${2:-unknown}"

    echo
    print_separator
    echo "ERROR: Installation failed"
    echo "Line      : ${line_number}"
    echo "Exit code : ${exit_code}"
    echo "Command   : ${command_name}"
    print_separator
    echo
    echo "Review the error shown immediately above this message."
    echo "After correcting the problem, run the script again."
    echo

    exit "${exit_code}"
}

trap 'error_handler "${LINENO}" "${BASH_COMMAND}"' ERR

# ----------------------------------------------------------------
# Cleanup helper
# ----------------------------------------------------------------

deactivate_existing_venv() {
    if [[ -n "${VIRTUAL_ENV:-}" ]]; then
        echo
        echo "An existing virtual environment is active:"
        echo "  ${VIRTUAL_ENV}"
        echo
        echo "It will not be used by this installer."
        echo "The installer will use:"
        echo "  ${VENV_PATH}"
        echo

        # Remove virtual-environment variables from the installer process.
        unset VIRTUAL_ENV || true
        unset PYTHONHOME || true

        # Remove a leading active-venv bin directory from PATH when possible.
        if [[ -n "${PATH:-}" ]]; then
            PATH="$(
                printf '%s' "${PATH}" |
                    awk -v RS=: -v ORS=: \
                        -v old_venv="${VIRTUAL_ENV:-}" \
                        '$0 != old_venv "/bin" { print }' |
                    sed 's/:$//'
            )"
            export PATH
        fi
    fi
}

# ----------------------------------------------------------------
# Operating-system detection
# ----------------------------------------------------------------

detect_operating_system() {
    if [[ ! -r /etc/os-release ]]; then
        print_error "Unable to read /etc/os-release."
        exit 1
    fi

    # shellcheck disable=SC1091
    source /etc/os-release

    OS_ID="${ID:-unknown}"
    OS_VERSION_ID="${VERSION_ID:-unknown}"
    OS_CODENAME="${VERSION_CODENAME:-${UBUNTU_CODENAME:-unknown}}"
    OS_PRETTY_NAME="${PRETTY_NAME:-unknown}"

    if [[ "${OS_ID}" != "ubuntu" ]]; then
        print_error "This installer currently supports Ubuntu only."
        echo "Detected operating system:"
        echo "  ${OS_PRETTY_NAME}"
        exit 1
    fi
}

# ----------------------------------------------------------------
# Repository validation
# ----------------------------------------------------------------

validate_repository() {
    local missing_items=()

    [[ -f "${REPO_ROOT}/requirements.txt" ]] ||
        missing_items+=("requirements.txt")

    [[ -f "${REPO_ROOT}/docker-compose.yml" ]] ||
        [[ -f "${REPO_ROOT}/compose.yml" ]] ||
        [[ -f "${REPO_ROOT}/compose.yaml" ]] ||
        [[ -f "${REPO_ROOT}/docker-compose.yaml" ]] ||
        missing_items+=("docker-compose.yml or compose.yml")

    if (( ${#missing_items[@]} > 0 )); then
        print_error "Required repository files were not found."

        echo "Repository root:"
        echo "  ${REPO_ROOT}"
        echo
        echo "Missing:"
        printf '  - %s\n' "${missing_items[@]}"
        echo
        echo "Expected script location:"
        echo "  exam-new-v3/scripts/install_ec2_dependencies.sh"
        echo

        exit 1
    fi
}

# ----------------------------------------------------------------
# Check whether an apt package has an installable candidate
# ----------------------------------------------------------------

apt_package_available() {
    local package_name="$1"
    local candidate

    candidate="$(
        apt-cache policy "${package_name}" 2>/dev/null |
            awk '/Candidate:/ {print $2; exit}'
    )"

    [[ -n "${candidate}" && "${candidate}" != "(none)" ]]
}

# ----------------------------------------------------------------
# Install Python using apt
# ----------------------------------------------------------------

install_python_packages_from_apt() {
    local python_bin="$1"

    local packages=(
        "${python_bin}"
        "${python_bin}-venv"
        "${python_bin}-dev"
    )

    local package_name

    for package_name in "${packages[@]}"; do
        if ! apt_package_available "${package_name}"; then
            return 1
        fi
    done

    sudo DEBIAN_FRONTEND=noninteractive apt-get install -y \
        "${packages[@]}"
}

# ----------------------------------------------------------------
# Add deadsnakes PPA where applicable
# ----------------------------------------------------------------

try_deadsnakes_ppa() {
    echo
    echo "Python ${REQUIRED_PYTHON_MAJOR_MINOR} is not available from"
    echo "the currently configured Ubuntu repositories."
    echo
    echo "Attempting to use the deadsnakes PPA..."

    if ! command -v add-apt-repository >/dev/null 2>&1; then
        sudo DEBIAN_FRONTEND=noninteractive apt-get install -y \
            software-properties-common
    fi

    # The PPA command itself can fail on unsupported/new Ubuntu releases.
    if ! sudo add-apt-repository -y ppa:deadsnakes/ppa; then
        print_warning \
            "The deadsnakes PPA does not support this Ubuntu release or could not be added."
        return 1
    fi

    sudo apt-get update

    if install_python_packages_from_apt "${PYTHON_BIN}"; then
        return 0
    fi

    return 1
}

# ----------------------------------------------------------------
# Install and validate selected Python
# ----------------------------------------------------------------

ensure_python() {
    echo
    echo "Required project Python : ${REQUIRED_PYTHON_MAJOR_MINOR}"
    echo "Selected Python command : ${PYTHON_BIN}"

    if command -v "${PYTHON_BIN}" >/dev/null 2>&1; then
        echo "${PYTHON_BIN} is already installed."
    else
        echo
        echo "${PYTHON_BIN} is not currently installed."
        echo "Checking configured Ubuntu repositories..."

        if install_python_packages_from_apt "${PYTHON_BIN}"; then
            echo "${PYTHON_BIN} was installed from Ubuntu repositories."
        elif try_deadsnakes_ppa; then
            echo "${PYTHON_BIN} was installed using the deadsnakes PPA."
        else
            print_error \
                "Python ${REQUIRED_PYTHON_MAJOR_MINOR} could not be installed."

            echo "Detected operating system:"
            echo "  Name     : ${OS_PRETTY_NAME}"
            echo "  Version  : ${OS_VERSION_ID}"
            echo "  Codename : ${OS_CODENAME}"
            echo
            echo "The current Ubuntu release does not provide installable"
            echo "packages for:"
            echo
            echo "  ${PYTHON_BIN}"
            echo "  ${PYTHON_BIN}-venv"
            echo "  ${PYTHON_BIN}-dev"
            echo
            echo "Recommended permanent solution:"
            echo
            echo "  Create an EC2 instance using:"
            echo "  Ubuntu Server 24.04 LTS x86_64"
            echo
            echo "Ubuntu 24.04 provides Python 3.12 as its standard"
            echo "system Python and is the recommended platform for this lab."
            echo
            echo "Do not use Python 3.14 for this project because some"
            echo "TensorFlow and scientific packages may not support it."
            echo

            exit 1
        fi
    fi

    # Ensure the venv and development packages are installed even when
    # the interpreter itself was already present.
    if apt_package_available "${PYTHON_BIN}-venv" &&
        apt_package_available "${PYTHON_BIN}-dev"; then

        sudo DEBIAN_FRONTEND=noninteractive apt-get install -y \
            "${PYTHON_BIN}-venv" \
            "${PYTHON_BIN}-dev"
    fi

    local detected_version
    local detected_major_minor
    local python_executable

    detected_version="$(
        "${PYTHON_BIN}" -c \
            'import sys; print(".".join(map(str, sys.version_info[:3])))'
    )"

    detected_major_minor="$(
        "${PYTHON_BIN}" -c \
            'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")'
    )"

    python_executable="$(
        "${PYTHON_BIN}" -c \
            'import sys; print(sys.executable)'
    )"

    echo
    echo "Selected Python:"
    echo "  Version    : ${detected_version}"
    echo "  Executable : ${python_executable}"

    if [[ "${detected_major_minor}" != "${REQUIRED_PYTHON_MAJOR_MINOR}" ]]; then
        print_error \
            "The selected interpreter is Python ${detected_major_minor}, but this project requires Python ${REQUIRED_PYTHON_MAJOR_MINOR}."

        echo "Run the script using:"
        echo
        echo "  PYTHON_BIN=python3.12 ./scripts/install_ec2_dependencies.sh"
        echo

        exit 1
    fi
}

# ----------------------------------------------------------------
# Configure Docker
# ----------------------------------------------------------------

configure_docker() {
    sudo systemctl enable docker
    sudo systemctl start docker

    if sudo systemctl is-active --quiet docker; then
        echo "Docker service is active."
    else
        print_error "Docker service failed to start."

        sudo systemctl status docker --no-pager || true

        exit 1
    fi

    if ! getent group docker >/dev/null 2>&1; then
        echo "Creating docker group..."
        sudo groupadd docker
    fi

    if id -nG "${CURRENT_USER}" |
        tr ' ' '\n' |
        grep -qx "docker"; then

        echo "User '${CURRENT_USER}' is already listed in the docker group."
    else
        echo "Adding user '${CURRENT_USER}' to the docker group..."
        sudo usermod -aG docker "${CURRENT_USER}"
        echo "User '${CURRENT_USER}' was added to the docker group."
    fi
}

# ----------------------------------------------------------------
# Back up an incompatible virtual environment
# ----------------------------------------------------------------

prepare_virtual_environment_directory() {
    local selected_major_minor
    local existing_major_minor
    local backup_name

    selected_major_minor="$(
        "${PYTHON_BIN}" -c \
            'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")'
    )"

    if [[ ! -e "${VENV_PATH}" ]]; then
        echo "No existing virtual environment was found."
        return 0
    fi

    if [[ ! -d "${VENV_PATH}" ]]; then
        backup_name="${VENV_PATH}.invalid.$(date +%Y%m%d_%H%M%S)"

        echo "The existing venv path is not a directory."
        echo "Moving it to:"
        echo "  ${backup_name}"

        mv "${VENV_PATH}" "${backup_name}"
        return 0
    fi

    if [[ ! -x "${VENV_PATH}/bin/python" ]]; then
        backup_name="${VENV_PATH}.invalid.$(date +%Y%m%d_%H%M%S)"

        echo "The existing '${VENV_DIR}' directory is not a valid"
        echo "Python virtual environment."
        echo
        echo "Moving it to:"
        echo "  ${backup_name}"

        mv "${VENV_PATH}" "${backup_name}"
        return 0
    fi

    existing_major_minor="$(
        "${VENV_PATH}/bin/python" -c \
            'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")'
    )"

    echo "Existing venv Python : ${existing_major_minor}"
    echo "Required Python      : ${selected_major_minor}"

    if [[ "${existing_major_minor}" != "${selected_major_minor}" ]]; then
        backup_name="${VENV_PATH}.python-${existing_major_minor}.backup.$(
            date +%Y%m%d_%H%M%S
        )"

        echo
        echo "The existing virtual environment uses an incompatible"
        echo "Python version."
        echo
        echo "Moving it to:"
        echo "  ${backup_name}"

        mv "${VENV_PATH}" "${backup_name}"
    else
        echo "The existing virtual environment uses the correct"
        echo "Python version."
    fi
}

# ----------------------------------------------------------------
# Create or validate virtual environment
# ----------------------------------------------------------------

create_virtual_environment() {
    if [[ ! -d "${VENV_PATH}" ]]; then
        echo "Creating virtual environment with ${PYTHON_BIN}..."

        "${PYTHON_BIN}" -m venv "${VENV_PATH}"

        echo "Virtual environment created successfully."
    else
        echo "Reusing the existing compatible virtual environment."
    fi

    if [[ ! -x "${VENV_PATH}/bin/python" ]]; then
        print_error "Virtual environment Python executable was not created."
        exit 1
    fi

    if [[ ! -x "${VENV_PATH}/bin/pip" ]]; then
        echo "Pip executable is missing; bootstrapping pip..."

        "${VENV_PATH}/bin/python" -m ensurepip --upgrade
    fi

    local venv_version
    local venv_major_minor
    local venv_executable

    venv_version="$(
        "${VENV_PATH}/bin/python" -c \
            'import sys; print(".".join(map(str, sys.version_info[:3])))'
    )"

    venv_major_minor="$(
        "${VENV_PATH}/bin/python" -c \
            'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")'
    )"

    venv_executable="$(
        "${VENV_PATH}/bin/python" -c \
            'import sys; print(sys.executable)'
    )"

    echo
    echo "Virtual environment:"
    echo "  Path       : ${VENV_PATH}"
    echo "  Python     : ${venv_version}"
    echo "  Executable : ${venv_executable}"

    if [[ "${venv_major_minor}" != "${REQUIRED_PYTHON_MAJOR_MINOR}" ]]; then
        print_error \
            "The virtual environment does not use Python ${REQUIRED_PYTHON_MAJOR_MINOR}."
        exit 1
    fi
}

# ----------------------------------------------------------------
# Install project Python dependencies
# ----------------------------------------------------------------

install_python_dependencies() {
    local venv_python="${VENV_PATH}/bin/python"

    echo "Upgrading pip, setuptools, and wheel..."

    "${venv_python}" -m pip install \
        --upgrade \
        pip \
        setuptools \
        wheel

    echo
    echo "Installing packages from requirements.txt..."

    "${venv_python}" -m pip install \
        --requirement "${REPO_ROOT}/requirements.txt"
}

# ----------------------------------------------------------------
# Verify Python imports
# ----------------------------------------------------------------

verify_python_imports() {
    local venv_python="${VENV_PATH}/bin/python"

    "${venv_python}" -m pip check

    echo
    echo "Core package verification:"

    "${venv_python}" - <<'PYTHON_CHECK'
import importlib
import sys

print(f"Python executable : {sys.executable}")
print(f"Python version    : {sys.version.split()[0]}")

packages = {
    "numpy": "NumPy",
    "pandas": "Pandas",
    "sklearn": "Scikit-learn",
    "tensorflow": "TensorFlow",
}

for module_name, display_name in packages.items():
    try:
        module = importlib.import_module(module_name)
        version = getattr(module, "__version__", "version not exposed")
        print(f"{display_name:<18}: {version}")
    except ModuleNotFoundError:
        print(
            f"{display_name:<18}: not installed "
            f"(acceptable only if it is not listed in requirements.txt)"
        )
    except Exception as exc:
        print(f"{display_name:<18}: import failed: {exc}")
        raise
PYTHON_CHECK
}

# ----------------------------------------------------------------
# Start
# ----------------------------------------------------------------

deactivate_existing_venv
detect_operating_system

echo
print_separator
echo "Topic 127 — EC2 Dependency Installation"
print_separator
echo "Repository root : ${REPO_ROOT}"
echo "Operating system: ${OS_PRETTY_NAME}"
echo "Ubuntu codename : ${OS_CODENAME}"
echo "Python command   : ${PYTHON_BIN}"
echo "Required Python  : ${REQUIRED_PYTHON_MAJOR_MINOR}"
echo "Virtual env      : ${VENV_PATH}"
echo "Current user     : ${CURRENT_USER}"
print_separator

cd "${REPO_ROOT}"

validate_repository

# ----------------------------------------------------------------
# Step 1: Update package index
# ----------------------------------------------------------------

print_step "1" "Updating Ubuntu package index..."

sudo apt-get update

# A full operating-system upgrade is intentionally not performed.
# Run it separately only when required:
#
#   sudo apt-get upgrade -y

# ----------------------------------------------------------------
# Step 2: Install common dependencies
# ----------------------------------------------------------------

print_step "2" "Installing common system dependencies..."

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
# Step 3: Install and validate Python 3.12
# ----------------------------------------------------------------

print_step "3" \
    "Installing and validating Python ${REQUIRED_PYTHON_MAJOR_MINOR}..."

ensure_python

# ----------------------------------------------------------------
# Step 4: Configure Docker
# ----------------------------------------------------------------

print_step "4" "Configuring Docker service and permissions..."

configure_docker

# ----------------------------------------------------------------
# Step 5: Check existing virtual environment
# ----------------------------------------------------------------

print_step "5" "Checking the existing virtual environment..."

prepare_virtual_environment_directory

# ----------------------------------------------------------------
# Step 6: Create virtual environment
# ----------------------------------------------------------------

print_step "6" \
    "Creating or reusing the Python ${REQUIRED_PYTHON_MAJOR_MINOR} virtual environment..."

create_virtual_environment

# ----------------------------------------------------------------
# Step 7: Install Python dependencies
# ----------------------------------------------------------------

print_step "7" "Installing Python dependencies..."

install_python_dependencies

# ----------------------------------------------------------------
# Step 8: Verification
# ----------------------------------------------------------------

print_step "8" "Verifying the installation..."

verify_python_imports

echo
echo "Python:"
"${VENV_PATH}/bin/python" --version

echo
echo "Pip:"
"${VENV_PATH}/bin/python" -m pip --version

echo
echo "Docker:"
docker --version

echo
echo "Docker Compose:"
docker compose version

echo
echo "Docker service:"
sudo systemctl is-active docker

echo
echo "Testing Docker daemon through sudo..."

if sudo docker info >/dev/null 2>&1; then
    echo "Docker daemon is responding correctly."
else
    print_error \
        "Docker is installed, but the Docker daemon is not responding."

    echo "Check Docker using:"
    echo
    echo "  sudo systemctl status docker"
    echo

    exit 1
fi

# ----------------------------------------------------------------
# Check whether Docker group is active in current shell
# ----------------------------------------------------------------

DOCKER_GROUP_ACTIVE=false

if id -nG |
    tr ' ' '\n' |
    grep -qx "docker"; then

    DOCKER_GROUP_ACTIVE=true
fi

# ----------------------------------------------------------------
# Final result
# ----------------------------------------------------------------

echo
print_separator
echo "Installation completed successfully"
print_separator
echo
echo "Operating system:"
echo "  ${OS_PRETTY_NAME}"
echo
echo "Repository:"
echo "  ${REPO_ROOT}"
echo
echo "Virtual environment:"
echo "  ${VENV_PATH}"
echo
echo "Project Python:"
"${VENV_PATH}/bin/python" --version
echo
echo "Activate the virtual environment later with:"
echo
echo "  cd ${REPO_ROOT}"
echo "  source ${VENV_DIR}/bin/activate"
echo

if [[ "${DOCKER_GROUP_ACTIVE}" == "true" ]]; then
    echo "Docker group permission is active in this SSH session."
    echo
    echo "Verify Docker without sudo:"
    echo
    echo "  docker ps"
else
    print_separator
    echo "IMPORTANT: Docker permission requires a new login session"
    print_separator
    echo
    echo "The user '${CURRENT_USER}' has been added to the docker group."
    echo
    echo "The new group permission is not active in the current"
    echo "SSH session yet."
    echo
    echo "Recommended method:"
    echo
    echo "  1. Exit the current EC2 SSH session:"
    echo
    echo "     exit"
    echo
    echo "  2. Connect to the EC2 instance again."
    echo
    echo "  3. Return to the repository:"
    echo
    echo "     cd ${REPO_ROOT}"
    echo
    echo "  4. Verify Docker without sudo:"
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
echo "  cd ${REPO_ROOT}"
echo "  docker compose up -d"
echo
echo "Check container status with:"
echo
echo "  docker compose ps"
echo
print_separator
