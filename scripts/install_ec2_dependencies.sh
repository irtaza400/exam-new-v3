#!/usr/bin/env bash
set -euo pipefail

sudo apt update && sudo apt upgrade -y

sudo apt install -y \
  python3 python3-venv python3-pip \
  git curl wget unzip jq \
  docker.io docker-compose-v2 \
  mosquitto-clients \
  apt-transport-https gnupg lsb-release

sudo systemctl enable --now docker

python3 -m venv venv
source venv/bin/activate
pip install --upgrade pip
pip install -r requirements.txt

echo "Installation complete. If Docker permission issue occurs, run: newgrp docker"
