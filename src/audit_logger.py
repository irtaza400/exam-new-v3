import csv
import os
from datetime import datetime, timezone

AUDIT_FILE = "reports/audit_log.csv"
os.makedirs("reports", exist_ok=True)


def write_audit(actor: str, action: str, target: str, result: str) -> None:
    file_exists = os.path.exists(AUDIT_FILE)
    with open(AUDIT_FILE, "a", newline="") as f:
        writer = csv.writer(f)
        if not file_exists:
            writer.writerow(["timestamp", "actor", "action", "target", "result"])
        writer.writerow([datetime.now(timezone.utc).isoformat(), actor, action, target, result])


if __name__ == "__main__":
    events = [
        ("operator", "view_dashboard", "grafana_cleanroom_dashboard", "success"),
        ("process_validator", "validate_recipe", "approved_recipe.json", "success"),
        ("security_engine", "scan_source_code", "src", "completed"),
        ("ehs_engine", "create_safety_incident", "etching_zone", "completed"),
        ("supply_chain", "verify_supplier_batch", "BATCH-003", "review_required"),
    ]
    for event in events:
        write_audit(*event)
    print(f"Audit log written to {AUDIT_FILE}")
