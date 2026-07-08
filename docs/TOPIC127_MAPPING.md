# Topic 127 Mapping

| Topic 127 Requirement | Phase 1 Component |
|---|---|
| IoT monitoring | Mosquitto MQTT |
| Sensor time-series storage | InfluxDB |
| Dashboard visualization | Grafana |
| Cloud-native deployment | Docker Compose |
| EC2 runnable platform | install/start scripts |

## Phase 2 Additions

| Topic 127 Requirement | Phase 2 File |
|---|---|
| Real-time particle counting | `src/sensor_simulator.py` |
| Temperature/humidity/airflow monitoring | `src/sensor_simulator.py` |
| MQTT IoT communication | `src/sensor_simulator.py`, `src/mqtt_to_influx.py` |
| Time-series data storage | `src/mqtt_to_influx.py` + InfluxDB |
| ML contamination detection | `src/ml_anomaly_engine.py` |
| Automated incident creation | `reports/incidents.csv`, `reports/incidents.jsonl` |
| Remediation workflow | `src/ml_anomaly_engine.py` recommended actions |

## Phase 3 additions

| Topic 127 Objective | Phase 3 Component |
|---|---|
| Process control monitoring | OPC-UA server/client, Modbus server/client |
| Nanolithography/deposition/etching monitoring | OPC-UA process variables |
| Out-of-specification detection | OPC-UA and Modbus validators |
| Tamper detection | SHA-256 recipe integrity checker |
| Critical equipment security controls | Process security incident reports |
| ICS/SCADA frameworks | OPC-UA and Modbus protocol simulators |

## TensorFlow Add-on Mapping

| Topic 127 Requirement | TensorFlow Add-on Coverage |
|---|---|
| ML/Analytics: TensorFlow | Implemented in `src/tensorflow_anomaly_engine.py` |
| AI-driven contamination detection | TensorFlow/Keras autoencoder detects abnormal cleanroom patterns |
| Environmental anomaly detection | Temperature, humidity, airflow, gas and PPE features included |
| Incident evidence | Output saved to `reports/tensorflow_anomaly_incidents.csv` |
