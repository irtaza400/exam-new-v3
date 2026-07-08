# EC2 Deployment Guide

## Recommended EC2
- Ubuntu 24.04 LTS
- t3.medium or larger
- 20 GB storage

## Security Group
Open for demo only:
- 22 SSH
- 3000 Grafana
- 8086 InfluxDB
- 1883 MQTT
- 4840 OPC-UA
- 5020 Modbus test port

## Commands
```bash
git clone https://github.com/YOUR_USERNAME/YOUR_REPO.git
cd YOUR_REPO
chmod +x scripts/*.sh
./scripts/install_ec2_dependencies.sh
./scripts/start_platform.sh
./scripts/run_complete_lab.sh
```
