# Topic 127 Version 3 Architecture

```text
Cleanroom Sensors / Simulators
        |
        v
MQTT Broker - Mosquitto
        |
        v
Python Ingestion Service
        |
        v
InfluxDB Time-Series Storage
        |
        v
Grafana Dashboard
```

Later phases add ML anomaly detection, OPC-UA, Modbus, EHS, supply chain, compliance and DevSecOps.

## Phase 3 — Process Control Security

```text
OPC-UA Server -> OPC-UA Validator -> process_security_incidents.csv
Modbus Server -> Modbus Validator -> modbus_security_incidents.csv
Approved Recipe -> SHA-256 Check -> recipe_tamper_incidents.csv
```

## TensorFlow/Keras Autoencoder Layer

```text
Cleanroom feature vector
  ├── particle_count
  ├── temperature
  ├── humidity
  ├── airflow
  ├── gas_ppm
  └── ppe_compliant
        ↓
TensorFlow/Keras Autoencoder
        ↓
Reconstruction Error Threshold
        ↓
Anomaly / Normal Decision
        ↓
reports/tensorflow_anomaly_incidents.csv
```
