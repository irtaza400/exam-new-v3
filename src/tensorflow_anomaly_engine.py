"""
TensorFlow/Keras anomaly detection module for Topic 127 Version 3.

Purpose:
- Adds TensorFlow coverage to the ML/Analytics objective.
- Uses a small autoencoder neural network to learn normal cleanroom behaviour.
- Flags abnormal particle, temperature, humidity, airflow, gas, and PPE readings.
- Generates a TensorFlow incident report for examiner evidence.

This module is EC2-friendly and CPU-only. It does not require GPU.
"""

import csv
import os
from datetime import datetime, timezone

import numpy as np

try:
    import tensorflow as tf
    from tensorflow import keras
    from tensorflow.keras import layers
except Exception as exc:
    raise SystemExit(
        "TensorFlow is not installed in this environment.\n"
        "Install dependencies first with: ./scripts/install_ec2_dependencies.sh\n"
        "Or manually run: source venv/bin/activate && pip install tensorflow\n"
        f"Original import error: {exc}"
    )

REPORT = "reports/tensorflow_anomaly_incidents.csv"
os.makedirs("reports", exist_ok=True)

np.random.seed(42)
tf.random.set_seed(42)

# Normal cleanroom training data.
# Columns:
# particle_count, temperature, humidity, airflow, gas_ppm, ppe_compliant
normal_data = np.column_stack([
    np.random.normal(350, 80, 500),       # normal particles
    np.random.normal(22.0, 1.0, 500),     # normal temperature
    np.random.normal(45.0, 4.0, 500),     # normal humidity
    np.random.normal(0.50, 0.08, 500),    # normal airflow
    np.random.normal(12.0, 5.0, 500),     # normal gas level
    np.ones(500),                         # PPE compliant
])

normal_data = np.clip(normal_data, a_min=0, a_max=None)

# Simple min-max scaling for compact EC2 demo.
min_vals = normal_data.min(axis=0)
max_vals = normal_data.max(axis=0)
scale = np.where(max_vals - min_vals == 0, 1, max_vals - min_vals)
train_scaled = (normal_data - min_vals) / scale

# Small Keras autoencoder.
model = keras.Sequential([
    layers.Input(shape=(6,)),
    layers.Dense(8, activation="relu"),
    layers.Dense(3, activation="relu"),
    layers.Dense(8, activation="relu"),
    layers.Dense(6, activation="linear"),
])

model.compile(optimizer="adam", loss="mse")
model.fit(train_scaled, train_scaled, epochs=15, batch_size=32, verbose=0)

recon = model.predict(train_scaled, verbose=0)
train_errors = np.mean(np.square(train_scaled - recon), axis=1)
threshold = float(np.percentile(train_errors, 95))

# Demonstration events: some normal, some abnormal.
test_events = [
    {
        "zone": "Lithography",
        "particle_count": 380,
        "temperature": 22.4,
        "humidity": 44,
        "airflow": 0.52,
        "gas_ppm": 10,
        "ppe_compliant": 1,
    },
    {
        "zone": "Deposition",
        "particle_count": 1350,
        "temperature": 27.5,
        "humidity": 60,
        "airflow": 0.22,
        "gas_ppm": 18,
        "ppe_compliant": 1,
    },
    {
        "zone": "Etching",
        "particle_count": 420,
        "temperature": 22,
        "humidity": 43,
        "airflow": 0.48,
        "gas_ppm": 75,
        "ppe_compliant": 0,
    },
]


def explain_event(event):
    reasons = []
    if event["particle_count"] > 800:
        reasons.append("High particle contamination risk")
    if event["temperature"] > 26:
        reasons.append("Temperature out of specification")
    if event["humidity"] > 55:
        reasons.append("Humidity out of specification")
    if event["airflow"] < 0.30:
        reasons.append("Low airflow contamination risk")
    if event["gas_ppm"] > 50:
        reasons.append("Hazardous gas exposure")
    if event["ppe_compliant"] == 0:
        reasons.append("PPE non-compliance")
    return reasons


file_exists = os.path.exists(REPORT)

with open(REPORT, "a", newline="") as f:
    writer = csv.writer(f)
    if not file_exists:
        writer.writerow([
            "timestamp",
            "model",
            "zone",
            "reconstruction_error",
            "threshold",
            "severity",
            "incident_type",
            "recommended_action",
        ])

    print("TensorFlow version:", tf.__version__)
    print("Autoencoder threshold:", threshold)

    for event in test_events:
        vector = np.array([[
            event["particle_count"],
            event["temperature"],
            event["humidity"],
            event["airflow"],
            event["gas_ppm"],
            event["ppe_compliant"],
        ]], dtype=float)

        scaled = (vector - min_vals) / scale
        prediction = model.predict(scaled, verbose=0)
        error = float(np.mean(np.square(scaled - prediction)))
        reasons = explain_event(event)

        is_anomaly = error > threshold or bool(reasons)

        if is_anomaly:
            severity = "CRITICAL" if event["gas_ppm"] > 50 or event["ppe_compliant"] == 0 else "HIGH"
            action = "Create incident, isolate affected zone, notify EHS/security team, verify process equipment"
            writer.writerow([
                datetime.now(timezone.utc).isoformat(),
                "TensorFlow Keras Autoencoder",
                event["zone"],
                round(error, 6),
                round(threshold, 6),
                severity,
                "; ".join(reasons) if reasons else "Neural reconstruction anomaly",
                action,
            ])
            print("TF INCIDENT:", event["zone"], "error=", round(error, 6), "reasons=", reasons)
        else:
            print("TF NORMAL:", event["zone"], "error=", round(error, 6))

print(f"TensorFlow anomaly report written to {REPORT}")
