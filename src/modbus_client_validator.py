"""Topic 127 Phase 3: Modbus client validator for PLC/register security."""
from datetime import datetime, timezone
import csv
import os
import sys
from pymodbus.client import ModbusTcpClient

REPORT = "reports/modbus_security_incidents.csv"
os.makedirs("reports", exist_ok=True)


def write_incident(findings):
    file_exists = os.path.exists(REPORT)
    with open(REPORT, "a", newline="") as f:
        writer = csv.writer(f)
        if not file_exists:
            writer.writerow(["timestamp", "source", "severity", "findings", "recommended_action"])
        writer.writerow([
            datetime.now(timezone.utc).isoformat(),
            "Modbus",
            "HIGH",
            "; ".join(findings),
            "Check PLC register state, verify recipe lock, inspect chamber controls",
        ])


def main():
    client = ModbusTcpClient("localhost", port=5020)
    if not client.connect():
        print("ERROR: Could not connect to Modbus server on localhost:5020")
        sys.exit(1)

    try:
        result = client.read_holding_registers(address=0, count=5)
        if result.isError():
            print("Modbus read error:", result)
            sys.exit(1)

        motor_speed, valve_status, pressure, alarm_code, recipe_lock = result.registers
        print("Modbus readings:", {
            "motor_speed": motor_speed,
            "valve_status": valve_status,
            "pressure": pressure,
            "alarm_code": alarm_code,
            "recipe_lock": recipe_lock,
        })

        findings = []
        if motor_speed > 1400:
            findings.append("Motor speed out of approved range")
        if pressure < 90 or pressure > 110:
            findings.append("Chamber pressure out of approved range")
        if alarm_code != 0:
            findings.append(f"PLC alarm code detected: {alarm_code}")
        if recipe_lock != 1:
            findings.append("Recipe lock disabled on PLC")

        if findings:
            write_incident(findings)
            print("MODBUS SECURITY INCIDENT:", findings)
        else:
            print("Modbus PLC/register state normal")
    finally:
        client.close()


if __name__ == "__main__":
    main()
