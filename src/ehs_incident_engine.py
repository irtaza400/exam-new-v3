import csv
import json
import os
from datetime import datetime, timezone

EVENTS = "data/ehs_events.json"
REPORT = "reports/ehs_incidents.csv"
os.makedirs("reports", exist_ok=True)


def classify(event):
    issues = []
    if event["gas_ppm"] > 50:
        issues.append("Hazardous gas exposure")
    if not event["ppe_compliant"]:
        issues.append("PPE non-compliance")
    if event["spill_detected"]:
        issues.append("Chemical spill detected")
    if event["nanoparticle_exposure"] > 70:
        issues.append("High nanoparticle exposure")
    if event["waste_container_full"]:
        issues.append("Hazardous waste container full")
    if event["emission_ppm"] > 70:
        issues.append("Emission threshold exceeded")

    if event["gas_ppm"] > 50 or event["spill_detected"]:
        severity = "CRITICAL"
        action = "Evacuate zone, isolate process, notify EHS response team"
    elif issues:
        severity = "HIGH"
        action = "Stop local activity, raise incident ticket, supervisor review"
    else:
        severity = "NORMAL"
        action = "Continue monitoring"
    return severity, issues, action


def main():
    with open(EVENTS, "r", encoding="utf-8") as f:
        events = json.load(f)

    with open(REPORT, "w", newline="", encoding="utf-8") as f:
        writer = csv.writer(f)
        writer.writerow(["timestamp", "zone", "severity", "issues", "emergency_action"])
        for event in events:
            severity, issues, action = classify(event)
            if severity != "NORMAL":
                writer.writerow([datetime.now(timezone.utc).isoformat(), event["zone"], severity, "; ".join(issues), action])
                print("EHS INCIDENT:", event["zone"], severity, issues)
            else:
                print("EHS NORMAL:", event["zone"])

    print("EHS report written to", REPORT)


if __name__ == "__main__":
    main()
