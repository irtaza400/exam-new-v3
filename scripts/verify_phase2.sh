#!/usr/bin/env bash
set -euo pipefail

echo "[VERIFY PHASE 2] Checking files..."
for f in \
  src/sensor_simulator.py \
  src/mqtt_to_influx.py \
  src/ml_anomaly_engine.py \
  scripts/run_sensor_simulator.sh \
  scripts/run_mqtt_to_influx.sh \
  scripts/run_phase2_ml.sh; do
  test -f "$f" || { echo "Missing: $f"; exit 1; }
done

echo "[VERIFY PHASE 2] Checking Python syntax..."
source venv/bin/activate 2>/dev/null || true
python -m py_compile src/sensor_simulator.py src/mqtt_to_influx.py src/ml_anomaly_engine.py

echo "[VERIFY PHASE 2] Running ML incident demo..."
python src/ml_anomaly_engine.py

test -f reports/incidents.csv || { echo "Missing incidents.csv"; exit 1; }

echo "[VERIFY PHASE 2 COMPLETE]"
echo "Generated files:"
ls -la reports
