"""Topic 127 Phase 3: SHA-256 recipe integrity and tamper detection."""
import csv
from datetime import datetime, timezone
import hashlib
import os
import sys

RECIPE = "data/approved_recipe.json"
HASH_FILE = "data/approved_recipe.sha256"
REPORT = "reports/recipe_tamper_incidents.csv"

os.makedirs("reports", exist_ok=True)


def sha256_file(path):
    digest = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(8192), b""):
            digest.update(chunk)
    return digest.hexdigest()


def write_incident(current_hash, approved_hash):
    file_exists = os.path.exists(REPORT)
    with open(REPORT, "a", newline="") as f:
        writer = csv.writer(f)
        if not file_exists:
            writer.writerow(["timestamp", "severity", "incident", "current_hash", "approved_hash", "recommended_action"])
        writer.writerow([
            datetime.now(timezone.utc).isoformat(),
            "CRITICAL",
            "Manufacturing recipe tampering detected",
            current_hash,
            approved_hash,
            "Block production, restore approved recipe, notify OT security team",
        ])


def main():
    if not os.path.exists(RECIPE):
        print(f"ERROR: Missing {RECIPE}")
        sys.exit(1)
    if not os.path.exists(HASH_FILE):
        print(f"ERROR: Missing {HASH_FILE}")
        sys.exit(1)

    current_hash = sha256_file(RECIPE)
    with open(HASH_FILE, "r", encoding="utf-8") as f:
        approved_hash = f.read().split()[0]

    print("Current hash :", current_hash)
    print("Approved hash:", approved_hash)

    if current_hash != approved_hash:
        write_incident(current_hash, approved_hash)
        print("CRITICAL: Recipe tampering detected")
        return 2

    print("Recipe integrity verified")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
