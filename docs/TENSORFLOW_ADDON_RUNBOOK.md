# TensorFlow Add-on Runbook

## Purpose

This add-on brings TensorFlow/Keras into the Topic 127 Version 3 lab.

It implements a lightweight CPU-based autoencoder for cleanroom anomaly detection.

## Why added

Topic 127 lists ML/Analytics tools including TensorFlow and scikit-learn. The original Version 3 lab already used scikit-learn. This add-on adds TensorFlow coverage while keeping the project EC2-runnable.

## Files added

```text
src/tensorflow_anomaly_engine.py
scripts/run_tensorflow_ml.sh
scripts/verify_tensorflow_addon.sh
tests/test_tensorflow_addon.py
docs/TENSORFLOW_ADDON_RUNBOOK.md
```

## Requirement added

```text
tensorflow
```

## Run on EC2

Install dependencies first:

```bash
./scripts/install_ec2_dependencies.sh
```

Then run:

```bash
./scripts/run_tensorflow_ml.sh
```

Check generated report:

```bash
cat reports/tensorflow_anomaly_incidents.csv
```

## What the model does

The TensorFlow model learns normal cleanroom patterns:

- particle count
- temperature
- humidity
- airflow
- gas ppm
- PPE compliance

Then it identifies abnormal behaviour using reconstruction error.

## Examiner explanation

This module demonstrates TensorFlow/Keras-based neural anomaly detection for cleanroom contamination and safety events. It complements the scikit-learn anomaly engine and directly maps to the Topic 127 ML/Analytics tool requirement.

## Roman Urdu explanation

Is add-on me TensorFlow use hota hai. Model normal cleanroom readings seekhta hai. Agar particles zyada hon, temperature abnormal ho, airflow low ho, gas zyada ho, ya PPE missing ho to model anomaly detect karta hai aur incident report generate hoti hai.
