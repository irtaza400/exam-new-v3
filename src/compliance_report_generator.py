import os
from datetime import datetime, timezone

os.makedirs("reports", exist_ok=True)

FILES = {
    "Cleanroom ML incidents": "reports/incidents.csv",
    "OPC-UA process security": "reports/process_security_incidents.csv",
    "Modbus process security": "reports/modbus_security_incidents.csv",
    "Recipe tamper incidents": "reports/recipe_tamper_incidents.csv",
    "Supply chain ledger": "reports/supply_chain_ledger.json",
    "Supply chain risk report": "reports/supply_chain_risk_report.csv",
    "EHS incidents": "reports/ehs_incidents.csv",
}


def status(path):
    return "Available" if os.path.exists(path) else "Not yet generated"


def main():
    report = []
    report.append("# Topic 127 Automated Compliance Report")
    report.append("")
    report.append(f"Generated: {datetime.now(timezone.utc).isoformat()}")
    report.append("")

    report.append("## Evidence Files")
    for name, path in FILES.items():
        report.append(f"- {name}: `{path}` — {status(path)}")
    report.append("")

    report.append("## ISO 14644 Cleanroom Monitoring")
    report.append("- Particle count, airflow, humidity and temperature data are modeled through IoT sensor streams.")
    report.append("- ML anomaly detection creates contamination and out-of-spec incidents.")
    report.append("")

    report.append("## ISO 14001 Environmental Management")
    report.append("- Emissions, spill events, hazardous waste state and environmental abnormality are documented.")
    report.append("- Compliance evidence is generated into reports for audit review.")
    report.append("")

    report.append("## OSHA / Worker Safety")
    report.append("- PPE non-compliance, gas exposure, spill events and nanoparticle exposure are monitored.")
    report.append("- Emergency response actions are automatically recommended.")
    report.append("")

    report.append("## EPA-style Environmental Reporting")
    report.append("- Emissions and hazardous waste events are captured as auditable records.")
    report.append("- This is a lab prototype, not a legal EPA filing system.")
    report.append("")

    report.append("## IEC 62443 / ICS Security")
    report.append("- OPC-UA and Modbus validation checks monitor industrial process values.")
    report.append("- Recipe SHA-256 integrity check detects unauthorized process recipe tampering.")
    report.append("")

    report.append("## Supply Chain Security")
    report.append("- Supplier certificates, quality status, batch traceability and export-risk flags are recorded.")
    report.append("- Blockchain-style hash chaining provides tamper-evident traceability.")
    report.append("")

    out = "\n".join(report) + "\n"
    with open("reports/compliance_report.md", "w", encoding="utf-8") as f:
        f.write(out)
    print(out)


if __name__ == "__main__":
    main()
