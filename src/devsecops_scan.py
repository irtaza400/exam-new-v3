import os
import shutil
import subprocess
from datetime import datetime, timezone

os.makedirs("reports", exist_ok=True)
SUMMARY = "reports/security_scan_report.txt"

commands = []

if shutil.which("bandit"):
    commands.append(["bandit", "-r", "src", "-f", "txt"])
else:
    commands.append(None)

if shutil.which("semgrep"):
    commands.append(["semgrep", "scan", "--config", "auto", "src"])
else:
    commands.append(None)

if shutil.which("trivy"):
    commands.append(["trivy", "fs", ".", "--severity", "HIGH,CRITICAL"])
else:
    commands.append(None)

with open(SUMMARY, "w") as f:
    f.write("Topic 127 DevSecOps Security Scan Report\n")
    f.write(f"Generated: {datetime.now(timezone.utc).isoformat()}\n")
    f.write("=" * 70 + "\n\n")

    tool_names = ["Bandit", "Semgrep", "Trivy"]
    for name, cmd in zip(tool_names, commands):
        f.write(f"\n--- {name} ---\n")
        if cmd is None:
            f.write(f"{name} not installed. Install on EC2 using scripts/install_ec2_dependencies.sh\n")
            continue
        try:
            result = subprocess.run(cmd, capture_output=True, text=True, timeout=120)
            f.write(result.stdout or "")
            f.write(result.stderr or "")
            f.write(f"\nExit code: {result.returncode}\n")
        except Exception as exc:
            f.write(f"Error running {name}: {exc}\n")

print(f"Security scan summary generated: {SUMMARY}")
