#!/usr/bin/env bash
set -euo pipefail

docker compose up -d

echo "Platform started."
echo "Grafana:  http://EC2_PUBLIC_IP:3000"
echo "InfluxDB: http://EC2_PUBLIC_IP:8086"
echo "MQTT:     localhost:1883"
echo "Grafana login: admin / admin12345"
