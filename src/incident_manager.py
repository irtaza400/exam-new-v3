import csv
import glob
import os
from datetime import datetime, timezone

REPORT = "reports/incident_summary.csv"
os.makedirs("reports", exist_ok=True)

SOURCE_FILES = [
    "reports/incidents.csv",
    "reports/process_security_incidents.csv",
    "reports/modbus_security_incidents.csv",
    "reports/recipe_tamper_incidents.csv",
    "reports/ehs_incidents.csv",
]


def classify_severity(row):
    text = " ".join(row).upper()
    if "CRITICAL" in text or "TAMPER" in text or "GAS" in text:
        return "CRITICAL"
    if "HIGH" in text or "OUT OF" in text or "ALARM" in text:
        return "HIGH"
    if "MEDIUM" in text:
        return "MEDIUM"
    return "INFO"


with open(REPORT, "w", newline="") as out:
    writer = csv.writer(out)
    writer.writerow(["generated_at", "source_file", "severity", "summary"])

    for path in SOURCE_FILES:
        if not os.path.exists(path):
            continue
        with open(path, newline="") as f:
            reader = csv.reader(f)
            rows = list(reader)
            for row in rows[1:]:
                if not row:
                    continue
                writer.writerow([
                    datetime.now(timezone.utc).isoformat(),
                    os.path.basename(path),
                    classify_severity(row),
                    " | ".join(row),
                ])

print(f"Central incident summary generated: {REPORT}")
