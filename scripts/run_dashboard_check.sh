#!/usr/bin/env bash
set -euo pipefail
source venv/bin/activate
python src/dashboard_healthcheck.py
