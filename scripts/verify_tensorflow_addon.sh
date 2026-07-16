#!/usr/bin/env bash
set -euo pipefail

missing=0

check_file() {
  if [ ! -f "$1" ]; then
    echo "MISSING: $1"
    missing=1
  else
    echo "OK: $1"
  fi
}

check_file requirements.txt
check_file src/tensorflow_anomaly_engine.py
check_file scripts/run_tensorflow_ml.sh
check_file docs/TENSORFLOW_ADDON_RUNBOOK.md
check_file tests/test_tensorflow_addon.py

grep -q '^tensorflow' requirements.txt && echo "OK: tensorflow exists in requirements.txt" || { echo "MISSING: tensorflow in requirements.txt"; missing=1; }

if [ "$missing" -eq 0 ]; then
  echo "TensorFlow add-on verification passed."
else
  echo "TensorFlow add-on verification failed."
  exit 1
fi
