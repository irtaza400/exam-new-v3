import csv
import json
import os
from datetime import datetime, timezone
from pathlib import Path

import numpy as np
from sklearn.ensemble import IsolationForest

REPORT = Path("reports/incidents.csv")
JSON_REPORT = Path("reports/incidents.jsonl")
REPORT.parent.mkdir(parents=True, exist_ok=True)


def classify_rules(row: dict) -> list[str]:
    reasons = []
    if row["particle_count"] > 800:
        reasons.append("High particle contamination")
    if row["temperature"] > 26:
        reasons.append("Temperature out of specification")
    if row["humidity"] > 55:
        reasons.append("Humidity out of specification")
    if row["airflow"] < 0.30:
        reasons.append("Low airflow contamination risk")
    if row["gas_ppm"] > 50:
        reasons.append("Hazardous gas exposure")
    if not row["ppe_compliant"]:
        reasons.append("PPE non-compliance")
    return reasons


def remediation_for(reasons: list[str]) -> str:
    if "Hazardous gas exposure" in reasons:
        return "Evacuate zone, isolate gas line, notify EHS response team"
    if "High particle contamination" in reasons:
        return "Pause process, increase filtration/airflow, inspect contamination source"
    if "PPE non-compliance" in reasons:
        return "Deny cleanroom access and notify safety supervisor"
    return "Create incident ticket and inspect affected process equipment"


def train_model() -> IsolationForest:
    normal_data = []
    for _ in range(400):
        normal_data.append([
            np.random.uniform(100, 650),
            np.random.uniform(20, 25),
            np.random.uniform(35, 52),
            np.random.uniform(0.35, 0.75),
            np.random.uniform(0, 35),
        ])
    model = IsolationForest(contamination=0.12, random_state=42)
    model.fit(normal_data)
    return model


def demo_events() -> list[dict]:
    return [
        {
            "zone": "Lithography",
            "process": "nanolithography",
            "machine_id": "EQP-100",
            "particle_count": 1450,
            "temperature": 27.4,
            "humidity": 59,
            "airflow": 0.24,
            "gas_ppm": 20,
            "ppe_compliant": True,
        },
        {
            "zone": "Etching",
            "process": "etching",
            "machine_id": "EQP-300",
            "particle_count": 420,
            "temperature": 22,
            "humidity": 42,
            "airflow": 0.51,
            "gas_ppm": 68,
            "ppe_compliant": False,
        },
        {
            "zone": "Deposition",
            "process": "deposition",
            "machine_id": "EQP-200",
            "particle_count": 260,
            "temperature": 23,
            "humidity": 44,
            "airflow": 0.55,
            "gas_ppm": 12,
            "ppe_compliant": True,
        },
    ]


def append_incident(row: dict, severity: str, reasons: list[str]) -> None:
    file_exists = REPORT.exists()
    action = remediation_for(reasons)
    timestamp = datetime.now(timezone.utc).isoformat()

    with REPORT.open("a", newline="") as f:
        writer = csv.writer(f)
        if not file_exists:
            writer.writerow([
                "timestamp", "zone", "process", "machine_id", "severity",
                "incident_type", "recommended_action"
            ])
        writer.writerow([
            timestamp,
            row["zone"],
            row["process"],
            row["machine_id"],
            severity,
            "; ".join(reasons),
            action,
        ])

    with JSON_REPORT.open("a") as f:
        f.write(json.dumps({
            "timestamp": timestamp,
            "zone": row["zone"],
            "process": row["process"],
            "machine_id": row["machine_id"],
            "severity": severity,
            "reasons": reasons,
            "recommended_action": action,
        }) + "\n")


def main() -> None:
    model = train_model()
    print("ML anomaly model trained using cleanroom baseline data.")

    for event in demo_events():
        vector = [[
            event["particle_count"],
            event["temperature"],
            event["humidity"],
            event["airflow"],
            event["gas_ppm"],
        ]]
        ml_prediction = model.predict(vector)[0]
        reasons = classify_rules(event)

        if ml_prediction == -1 and "ML statistical anomaly" not in reasons:
            reasons.append("ML statistical anomaly")

        if reasons:
            severity = "CRITICAL" if event["gas_ppm"] > 50 else "HIGH" if event["particle_count"] > 1000 else "MEDIUM"
            append_incident(event, severity, reasons)
            print("INCIDENT:", event["zone"], severity, reasons)
        else:
            print("NORMAL:", event["zone"], event["machine_id"])

    print(f"Reports generated: {REPORT}, {JSON_REPORT}")


if __name__ == "__main__":
    main()
