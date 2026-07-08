#!/usr/bin/env bash
set -euo pipefail

echo "Checking Docker containers..."
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

echo "Testing MQTT publish/subscribe..."
timeout 5 bash -c 'mosquitto_sub -h localhost -p 1883 -t topic127/test > /tmp/topic127_mqtt_test.txt &' || true
sleep 1
mosquitto_pub -h localhost -p 1883 -t topic127/test -m "phase1-ok"
sleep 1
cat /tmp/topic127_mqtt_test.txt || true

echo "Checking InfluxDB HTTP endpoint..."
curl -s http://localhost:8086/health || true

echo
echo "Phase 1 verification complete."
