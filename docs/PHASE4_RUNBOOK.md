# Phase 4 Runbook — Supply Chain, EHS and Compliance

## Purpose
Phase 4 adds Topic 127 safety, supply chain and compliance automation.

## Run

```bash
./scripts/run_supply_chain.sh
./scripts/run_ehs_engine.sh
./scripts/run_compliance_report.sh
./scripts/verify_phase4.sh
```

## Outputs

```text
reports/supply_chain_ledger.json
reports/supply_chain_risk_report.csv
reports/ehs_incidents.csv
reports/compliance_report.md
```

## Topic 127 Mapping

- Raw material traceability: `supply_chain_ledger.py`
- Supplier quality/authentication: `suppliers.json` and risk scoring
- Dual-use/export-controlled risk: `export_risk` field
- PPE compliance: `ehs_incident_engine.py`
- Hazardous gas/chemical/spill monitoring: `ehs_incident_engine.py`
- Emergency response: severity and action generation
- Environmental compliance: `compliance_report_generator.py`
- ISO 14644 / ISO 14001 / OSHA / EPA-style reporting: `compliance_report.md`
