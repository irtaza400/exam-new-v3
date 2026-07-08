# Phase 2 Runbook — IoT + ML Cleanroom Monitoring

## Purpose

Phase 2 adds working cleanroom data functionality:

- MQTT sensor simulator
- MQTT to InfluxDB ingestion service
- ML anomaly detection with scikit-learn
- Incident report generation

## Local/EC2 demo commands

Terminal 1:

```bash
./scripts/start_platform.sh
```

Terminal 2:

```bash
./scripts/run_sensor_simulator.sh
```

Terminal 3:

```bash
./scripts/run_mqtt_to_influx.sh
```

Terminal 4:

```bash
./scripts/run_phase2_ml.sh
```

## Verify phase

```bash
./scripts/verify_phase2.sh
```

## Examiner explanation

Phase 2 demonstrates AI-driven cleanroom monitoring. Sensor readings are published to MQTT, ingested into InfluxDB, visualized in Grafana, and evaluated by an ML anomaly engine. When contamination, airflow, gas, or PPE issues are found, incident reports are generated with recommended remediation actions.

## Roman Urdu explanation

Is phase me cleanroom sensor data generate hota hai. MQTT us data ko send karta hai. Python consumer data ko InfluxDB me save karta hai. ML model readings check karta hai aur agar particles high hon, gas leak ho, airflow low ho, ya PPE issue ho to incident report generate karta hai.
