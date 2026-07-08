#!/usr/bin/env bash
set -euo pipefail
source venv/bin/activate
mkdir -p reports logs
python src/project_orchestrator.py

echo "Running TensorFlow/Keras anomaly engine..."
./scripts/run_tensorflow_ml.sh || true
