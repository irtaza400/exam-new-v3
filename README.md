# Topic 127 – Version 3 Enterprise Practical Lab

## RQF Level 6 Diploma in AIOps

### Topic 127

**Orchestrating Advanced Nanotechnology Manufacturing Security Platform with Cleanroom Monitoring, Process Control, and Environmental Safety for Semiconductor and Advanced Materials Production**

---

# Project Overview

This repository implements an enterprise-style educational platform that demonstrates how AI, IoT, Industrial Control Systems (ICS), cybersecurity, DevSecOps, environmental compliance, and supply chain security can be integrated into a nanotechnology manufacturing environment.

The project is designed to be deployed on **AWS EC2 Ubuntu** and uses open-source technologies aligned with the Topic 127 specification.

---

# Project Architecture

```
Sensor Simulator
        │
        ▼
 MQTT (Mosquitto)
        │
        ▼
 MQTT Consumer
        │
        ▼
 InfluxDB
        │
        ▼
 Grafana Dashboard
        │
        ▼
 ML Anomaly Detection
        │
        ▼
 Incident Management
        │
        ▼
 Compliance Reporting
```

Industrial Process Layer

```
OPC-UA
      │
      ▼
Process Validator

Modbus
      │
      ▼
PLC Validator

Recipe Integrity
      │
      ▼
SHA256 Tamper Detection
```

Enterprise Layer

```
Supply Chain

EHS

Compliance

DevSecOps

Audit Logging

Final Reports
```

---

# Version 3 Phase Breakdown

## Phase 1

Foundation Platform

- Docker Compose
- MQTT
- InfluxDB
- Grafana
- Dashboard provisioning

---

## Phase 2

AI-driven Cleanroom Monitoring

- Sensor simulator
- MQTT publisher
- MQTT consumer
- scikit-learn anomaly detection
- TensorFlow anomaly detection
- Incident engine

---

## Phase 3

Manufacturing Process Control Security

- OPC-UA
- Modbus
- Recipe integrity
- SHA256 tamper detection
- Process validation

---

## Phase 4

Supply Chain + EHS + Compliance

- Supplier traceability
- Quality verification
- Risk assessment
- PPE monitoring
- Hazardous material monitoring
- Compliance reporting

---

## Phase 5

DevSecOps

- Bandit
- Semgrep
- Trivy
- Audit logging
- Dashboard health checks
- Final reporting
- Presentation evidence
- Viva preparation

---

# Folder Structure

```
topic127-v3-enterprise-lab/

config/
dashboards/
data/
docs/
logs/
models/
reports/
scripts/
security/
src/
tests/

docker-compose.yml
requirements.txt
README.md
```

---

# Technology Stack

## AI

- TensorFlow
- scikit-learn

## IoT

- Mosquitto MQTT

## Database

- InfluxDB

## Dashboard

- Grafana

## Process Control

- OPC-UA
- Modbus

## Supply Chain

- Ledger-based traceability

## Safety

- Custom EHS Engine

## DevSecOps

- Bandit
- Semgrep
- Trivy

---

# Topic 127 Learning Objective Coverage

✔ AI-driven cleanroom monitoring

✔ Environmental monitoring

✔ Contamination detection

✔ Manufacturing process control

✔ OPC-UA

✔ Modbus

✔ Recipe integrity

✔ Process security

✔ Supply chain traceability

✔ Worker safety

✔ PPE compliance

✔ Hazardous material monitoring

✔ Environmental compliance

✔ DevSecOps

✔ Audit logging

---

# EC2 Deployment

```
chmod +x scripts/*.sh

./scripts/install_ec2_dependencies.sh

./scripts/start_platform.sh

./scripts/run_complete_lab.sh
```

---

# Verification

```
./scripts/verify_phase1.sh

./scripts/verify_phase2.sh

./scripts/verify_phase3.sh

./scripts/verify_phase4.sh

./scripts/verify_phase5.sh

./scripts/verify_tensorflow_addon.sh
```

---

# Default Services

| Service | URL | Credentials |
|----------|-----|-------------|
| MQTT | localhost:1883 | Anonymous |
| InfluxDB | http://EC2_IP:8086 | admin / admin12345 |
| Grafana | http://EC2_IP:3000 | admin / admin12345 |

---

# Simulation vs Real Components

This project uses **real open-source software components** including MQTT, InfluxDB, Grafana, TensorFlow, scikit-learn, OPC-UA libraries, Modbus libraries, Bandit, Semgrep, and Trivy.

Physical semiconductor equipment, cleanroom sensors, PLCs, and manufacturing systems are represented by software simulators because they are not available in a cloud-based educational environment. The architecture is designed so simulated inputs can be replaced with real industrial devices.

---

# Intended Audience

This project is intended for:

- RQF Level 6 Diploma assessment
- Topic 127 presentation
- Technical viva demonstration
- AWS EC2 deployment
- GitHub portfolio

---

# Author

Version 3 Enterprise Practical Lab

Topic 127

RQF Level 6 Diploma in AIOps