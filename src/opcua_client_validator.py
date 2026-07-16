"""Topic 127 Phase 3: OPC-UA process validator.
Reads process-control values and produces process security incidents.
"""
from datetime import datetime, timezone
import csv
import os
import sys
from opcua import Client

REPORT = "reports/process_security_incidents.csv"
ENDPOINT = "opc.tcp://localhost:4840/topic127/opcua/server/"

os.makedirs("reports", exist_ok=True)


def write_incident(source, severity, findings, action):
    file_exists = os.path.exists(REPORT)
    with open(REPORT, "a", newline="") as f:
        writer = csv.writer(f)
        if not file_exists:
            writer.writerow(["timestamp", "source", "severity", "findings", "recommended_action"])
        writer.writerow([datetime.now(timezone.utc).isoformat(), source, severity, "; ".join(findings), action])


def main():
    client = Client(ENDPOINT)
    try:
        client.connect()
        objects = client.get_objects_node()
        machine = objects.get_child(["2:NanoManufacturingMachine"])

        recipe = machine.get_child(["2:RecipeID"]).get_value()
        process = machine.get_child(["2:ProcessName"]).get_value()
        temp = float(machine.get_child(["2:TemperatureSetpoint"]).get_value())
        pressure = float(machine.get_child(["2:PressureSetpoint"]).get_value())
        etch = int(machine.get_child(["2:EtchTimeSeconds"]).get_value())
        status = machine.get_child(["2:MachineStatus"]).get_value()
        security = machine.get_child(["2:SecurityState"]).get_value()

        print("OPC-UA readings:")
        print({
            "recipe": recipe,
            "process": process,
            "temperature": temp,
            "pressure": pressure,
            "etch_time": etch,
            "status": status,
            "security_state": security,
        })

        findings = []
        if recipe != "RCP-LITHO-001":
            findings.append("Recipe mismatch detected")
        if process not in ["nanolithography", "deposition", "etching"]:
            findings.append("Unknown manufacturing process")
        if temp < 20 or temp > 25:
            findings.append("Temperature setpoint out of specification")
        if pressure < 0.90 or pressure > 1.10:
            findings.append("Pressure setpoint out of specification")
        if etch < 55 or etch > 65:
            findings.append("Etch time out of specification")
        if security != "NORMAL":
            findings.append("Equipment security state requires investigation")

        if findings:
            write_incident("OPC-UA", "HIGH", findings, "Validate equipment state, verify recipe, pause affected process if needed")
            print("PROCESS SECURITY INCIDENT:", findings)
        else:
            print("OPC-UA process parameters normal")
    except Exception as exc:
        print("OPC-UA validation error:", exc)
        sys.exit(1)
    finally:
        try:
            client.disconnect()
        except Exception:
            pass


if __name__ == "__main__":
    main()
