# Phase 1 Runbook

## Run on EC2

```bash
chmod +x scripts/*.sh
./scripts/install_ec2_dependencies.sh
./scripts/start_platform.sh
./scripts/verify_phase1.sh
```

## Open dashboards

- Grafana: `http://EC2_PUBLIC_IP:3000`
- Login: `admin / admin12345`

## Security group ports

- 22 SSH
- 3000 Grafana
- 8086 InfluxDB
- 1883 MQTT only if external testing is needed
