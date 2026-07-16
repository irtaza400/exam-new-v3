import os
from datetime import datetime, timezone

REPORT = "reports/final_project_report.md"
os.makedirs("reports", exist_ok=True)

files = {
    "Cleanroom ML incidents": "reports/incidents.csv",
    "OPC-UA process security": "reports/process_security_incidents.csv",
    "Modbus PLC security": "reports/modbus_security_incidents.csv",
    "Recipe tamper detection": "reports/recipe_tamper_incidents.csv",
    "EHS incidents": "reports/ehs_incidents.csv",
    "Supply chain ledger": "reports/supply_chain_ledger.json",
    "Compliance report": "reports/compliance_report.md",
    "Audit log": "reports/audit_log.csv",
    "Security scan report": "reports/security_scan_report.txt",
    "Incident summary": "reports/incident_summary.csv",
    "Dashboard healthcheck": "reports/dashboard_healthcheck.txt",
}

with open(REPORT, "w") as f:
    f.write("# Topic 127 Version 3 Final Project Report\n\n")
    f.write(f"Generated: {datetime.now(timezone.utc).isoformat()}\n\n")
    f.write("## Executive Summary\n\n")
    f.write("This EC2-ready enterprise lab implements a nanotechnology manufacturing security platform with IoT monitoring, AI anomaly detection, OPC-UA/Modbus process control security, supply chain traceability, worker safety, compliance automation, audit logging, and DevSecOps evidence.\n\n")
    f.write("## Evidence Files\n\n")
    for label, path in files.items():
        status = "PRESENT" if os.path.exists(path) else "MISSING - run related module"
        f.write(f"- {label}: `{path}` — **{status}**\n")

    f.write("\n## Topic 127 Mapping\n\n")
    f.write("- AI Cleanroom Monitoring: MQTT, InfluxDB, Grafana, ML anomaly engine\n")
    f.write("- Manufacturing Process Control Security: OPC-UA, Modbus, recipe integrity\n")
    f.write("- Supply Chain Security: supplier ledger, material traceability, dual-use risk flag\n")
    f.write("- Worker Safety: PPE, gas, spill, nanoparticle exposure incidents\n")
    f.write("- DevSecOps: Bandit, Semgrep, Trivy scan orchestration\n")
    f.write("- Compliance: ISO 14644, ISO 14001, OSHA, EPA, IEC 62443, NIST CSF evidence\n")

print(f"Final report generated: {REPORT}")
