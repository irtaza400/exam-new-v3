import json
import hashlib
import os
from datetime import datetime, timezone

SUPPLIERS = "data/suppliers.json"
LEDGER = "reports/supply_chain_ledger.json"
REPORT = "reports/supply_chain_risk_report.csv"
os.makedirs("reports", exist_ok=True)


def hash_block(block):
    encoded = json.dumps(block, sort_keys=True).encode("utf-8")
    return hashlib.sha256(encoded).hexdigest()


def load_chain():
    if os.path.exists(LEDGER):
        with open(LEDGER, "r", encoding="utf-8") as f:
            return json.load(f)
    return []


def save_chain(chain):
    with open(LEDGER, "w", encoding="utf-8") as f:
        json.dump(chain, f, indent=2)


def risk_score(supplier):
    score = 0
    if not supplier.get("certificate_valid"):
        score += 40
    if not supplier.get("approved"):
        score += 30
    if supplier.get("quality_status") != "PASSED":
        score += 20
    if supplier.get("export_risk") == "HIGH":
        score += 30
    elif supplier.get("export_risk") == "MEDIUM":
        score += 15
    return min(score, 100)


def decision(score):
    if score >= 70:
        return "REJECT_OR_LEGAL_REVIEW"
    if score >= 40:
        return "QUARANTINE_AND_QMS_REVIEW"
    return "APPROVE_FOR_USE"


def main():
    with open(SUPPLIERS, "r", encoding="utf-8") as f:
        suppliers = json.load(f)

    chain = load_chain()
    previous_hash = chain[-1]["hash"] if chain else "GENESIS"

    csv_lines = ["timestamp,supplier_id,material,batch,risk_score,decision"]

    for s in suppliers:
        score = risk_score(s)
        action = decision(score)
        block = {
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "supplier_id": s["supplier_id"],
            "supplier_name": s["name"],
            "material": s["material"],
            "batch": s["batch"],
            "certificate_valid": s["certificate_valid"],
            "quality_status": s["quality_status"],
            "export_risk": s["export_risk"],
            "approved_supplier": s["approved"],
            "risk_score": score,
            "decision": action,
            "previous_hash": previous_hash,
        }
        block["hash"] = hash_block(block)
        previous_hash = block["hash"]
        chain.append(block)
        csv_lines.append(f'{block["timestamp"]},{s["supplier_id"]},{s["material"]},{s["batch"]},{score},{action}')
        print("SUPPLY CHAIN:", s["supplier_id"], s["material"], "score=", score, "decision=", action)

    save_chain(chain)
    with open(REPORT, "w", encoding="utf-8") as f:
        f.write("\n".join(csv_lines) + "\n")

    print("Ledger written to", LEDGER)
    print("Risk report written to", REPORT)


if __name__ == "__main__":
    main()
