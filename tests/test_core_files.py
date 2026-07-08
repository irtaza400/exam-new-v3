import os


def test_core_files_exist():
    required = [
        "src/sensor_simulator.py",
        "src/mqtt_to_influx.py",
        "src/ml_anomaly_engine.py",
        "src/opcua_server.py",
        "src/modbus_server.py",
        "src/recipe_integrity_check.py",
        "src/supply_chain_ledger.py",
        "src/ehs_incident_engine.py",
        "src/compliance_report_generator.py",
        "src/project_orchestrator.py",
    ]
    missing = [p for p in required if not os.path.exists(p)]
    assert not missing, f"Missing files: {missing}"
