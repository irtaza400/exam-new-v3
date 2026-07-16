#!/usr/bin/env bash

# ================================================================
# Topic 127 / exam-new-v3
# Grafana Dashboard Validation
#
# Purpose:
#   Validate the provisioned dashboard JSON, datasource UID,
#   required six panels, required telemetry fields and aggregation.
#
# Usage:
#   chmod +x scripts/validate_grafana_dashboard.sh
#   ./scripts/validate_grafana_dashboard.sh
# ================================================================

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

DASHBOARD_FILE="${REPO_ROOT}/dashboards/json/topic127_cleanroom_dashboard.json"
DATASOURCE_FILE="${REPO_ROOT}/grafana/provisioning/datasources/influxdb.yml"

EXPECTED_DASHBOARD_UID="topic127-cleanroom"
EXPECTED_DATASOURCE_UID="influxdb-topic127"
EXPECTED_PANEL_COUNT=6

print_separator() {
    echo "============================================================"
}

fail() {
    echo
    print_separator
    echo "ERROR: $1"
    print_separator
    exit 1
}

success() {
    echo "OK: $1"
}

echo
print_separator
echo "Grafana Dashboard Validation"
print_separator
echo "Repository : ${REPO_ROOT}"
echo "Dashboard  : ${DASHBOARD_FILE}"
echo "Datasource : ${DATASOURCE_FILE}"
print_separator
echo

command -v python >/dev/null 2>&1 ||
    fail "Python command was not found."

[[ -f "${DASHBOARD_FILE}" ]] ||
    fail "Dashboard JSON was not found."

[[ -f "${DATASOURCE_FILE}" ]] ||
    fail "Grafana datasource provisioning file was not found."

python - "${DASHBOARD_FILE}" \
    "${DATASOURCE_FILE}" \
    "${EXPECTED_DASHBOARD_UID}" \
    "${EXPECTED_DATASOURCE_UID}" \
    "${EXPECTED_PANEL_COUNT}" <<'PY'
import json
import re
import sys
from pathlib import Path

dashboard_path = Path(sys.argv[1])
datasource_path = Path(sys.argv[2])
expected_dashboard_uid = sys.argv[3]
expected_datasource_uid = sys.argv[4]
expected_panel_count = int(sys.argv[5])

required_panels = {
    "Cleanroom Particle Count": "particle_count",
    "Cleanroom Temperature": "temperature",
    "Relative Humidity": "humidity",
    "Cleanroom Airflow": "airflow",
    "Hazardous Gas Concentration": "gas_ppm",
    "PPE Compliance": "ppe_compliant",
}

try:
    with dashboard_path.open(encoding="utf-8") as file:
        dashboard = json.load(file)
except json.JSONDecodeError as exc:
    raise SystemExit(
        f"ERROR: Invalid dashboard JSON: {exc}"
    ) from exc

dashboard_uid = dashboard.get("uid")
if dashboard_uid != expected_dashboard_uid:
    raise SystemExit(
        "ERROR: Dashboard UID mismatch.\n"
        f"Expected: {expected_dashboard_uid}\n"
        f"Found   : {dashboard_uid}"
    )

panels = dashboard.get("panels")
if not isinstance(panels, list):
    raise SystemExit("ERROR: Dashboard panels property is missing.")

if len(panels) != expected_panel_count:
    raise SystemExit(
        "ERROR: Incorrect panel count.\n"
        f"Expected: {expected_panel_count}\n"
        f"Found   : {len(panels)}"
    )

panel_ids = []
found_titles = set()

for panel in panels:
    panel_id = panel.get("id")
    panel_title = panel.get("title")
    panel_type = panel.get("type")
    datasource = panel.get("datasource", {})
    datasource_uid = datasource.get("uid")
    targets = panel.get("targets", [])

    if panel_id in panel_ids:
        raise SystemExit(
            f"ERROR: Duplicate panel ID detected: {panel_id}"
        )

    panel_ids.append(panel_id)

    if datasource_uid != expected_datasource_uid:
        raise SystemExit(
            "ERROR: Datasource UID mismatch in panel "
            f"'{panel_title}'.\n"
            f"Expected: {expected_datasource_uid}\n"
            f"Found   : {datasource_uid}"
        )

    if panel_title not in required_panels:
        raise SystemExit(
            f"ERROR: Unexpected panel title: {panel_title}"
        )

    expected_field = required_panels[panel_title]

    if not targets:
        raise SystemExit(
            f"ERROR: Panel '{panel_title}' has no query target."
        )

    combined_query = "\n".join(
        str(target.get("query", ""))
        for target in targets
    )

    if expected_field not in combined_query:
        raise SystemExit(
            "ERROR: Required field was not found in panel "
            f"'{panel_title}'.\n"
            f"Expected field: {expected_field}"
        )

    if "aggregateWindow" not in combined_query:
        raise SystemExit(
            "ERROR: aggregateWindow is missing from panel "
            f"'{panel_title}'."
        )

    if panel_title == "PPE Compliance":
        if panel_type != "stat":
            raise SystemExit(
                "ERROR: PPE Compliance must use a stat panel."
            )

        if "* 100.0" not in combined_query:
            raise SystemExit(
                "ERROR: PPE Compliance query does not convert "
                "the value to a percentage."
            )
    elif panel_type != "timeseries":
        raise SystemExit(
            f"ERROR: '{panel_title}' must use timeseries type."
        )

    found_titles.add(panel_title)

missing_titles = set(required_panels) - found_titles
if missing_titles:
    raise SystemExit(
        "ERROR: Missing panels: "
        + ", ".join(sorted(missing_titles))
    )

datasource_content = datasource_path.read_text(
    encoding="utf-8"
)

uid_pattern = re.compile(
    rf"^\s*uid:\s*{re.escape(expected_datasource_uid)}\s*$",
    re.MULTILINE,
)

if not uid_pattern.search(datasource_content):
    raise SystemExit(
        "ERROR: Expected datasource UID was not found in "
        f"{datasource_path}.\n"
        f"Expected: {expected_datasource_uid}"
    )

print("Dashboard JSON              : valid")
print(f"Dashboard UID               : {dashboard_uid}")
print(f"Datasource UID              : {expected_datasource_uid}")
print(f"Panel count                 : {len(panels)}")
print("Required telemetry fields   : present")
print("Flux aggregation            : present")
print("PPE percentage conversion   : present")
print()
print("Panels:")

for panel in panels:
    print(
        f"  {panel['id']}: "
        f"{panel['title']} "
        f"[{panel['type']}]"
    )
PY

echo
success "Grafana dashboard validation passed."
print_separator
