import json
import os
from datetime import datetime, timezone

DASHBOARD = "dashboards/json/topic127_cleanroom_dashboard.json"
REPORT = "reports/dashboard_healthcheck.txt"
os.makedirs("reports", exist_ok=True)

checks = []
checks.append(("dashboard_file_exists", os.path.exists(DASHBOARD)))

if os.path.exists(DASHBOARD):
    try:
        with open(DASHBOARD) as f:
            data = json.load(f)
        checks.append(("dashboard_json_valid", True))
        checks.append(("dashboard_has_title", bool(data.get("title") or data.get("dashboard", {}).get("title"))))
    except Exception:
        checks.append(("dashboard_json_valid", False))
        checks.append(("dashboard_has_title", False))

with open(REPORT, "w") as f:
    f.write("Topic 127 Dashboard Healthcheck\n")
    f.write(f"Generated: {datetime.now(timezone.utc).isoformat()}\n\n")
    for name, result in checks:
        f.write(f"{name}: {'PASS' if result else 'FAIL'}\n")

print(f"Dashboard healthcheck generated: {REPORT}")
