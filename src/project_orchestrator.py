import subprocess
import sys

commands = [
    [sys.executable, "src/ml_anomaly_engine.py"],
    [sys.executable, "src/recipe_integrity_check.py"],
    [sys.executable, "src/supply_chain_ledger.py"],
    [sys.executable, "src/ehs_incident_engine.py"],
    [sys.executable, "src/compliance_report_generator.py"],
    [sys.executable, "src/audit_logger.py"],
    [sys.executable, "src/incident_manager.py"],
    [sys.executable, "src/dashboard_healthcheck.py"],
    [sys.executable, "src/devsecops_scan.py"],
    [sys.executable, "src/final_report_generator.py"],
]

for cmd in commands:
    print("\n[ORCHESTRATOR] Running:", " ".join(cmd))
    subprocess.run(cmd, check=False)

print("\n[ORCHESTRATOR] Complete. Check reports/ folder.")
