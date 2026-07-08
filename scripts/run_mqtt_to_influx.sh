#!/usr/bin/env bash
set -euo pipefail
source venv/bin/activate
python src/mqtt_to_influx.py
