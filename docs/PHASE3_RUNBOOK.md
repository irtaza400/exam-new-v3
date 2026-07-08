# Phase 3 Runbook — Manufacturing Process Control and Security

Phase 3 adds real protocol simulators and validators:

- OPC-UA server/client for modern industrial integration
- Modbus TCP server/client for PLC/register monitoring
- SHA-256 recipe integrity checking
- Process security incident reporting

## Run OPC-UA demo

Terminal 1:

```bash
./scripts/run_opcua_server.sh
```

Terminal 2:

```bash
./scripts/run_opcua_validator.sh
cat reports/process_security_incidents.csv
```

## Run Modbus demo

Terminal 1:

```bash
./scripts/run_modbus_server.sh
```

Terminal 2:

```bash
./scripts/run_modbus_validator.sh
cat reports/modbus_security_incidents.csv
```

## Run recipe integrity check

```bash
./scripts/run_recipe_integrity.sh
```

To test tampering safely:

```bash
cp data/approved_recipe.json data/approved_recipe.backup.json
sed -i 's/60/90/' data/approved_recipe.json
./scripts/run_recipe_integrity.sh || true
cat reports/recipe_tamper_incidents.csv
mv data/approved_recipe.backup.json data/approved_recipe.json
```

## Topic 127 mapping

This phase covers:

- Manufacturing process control monitoring
- Nanolithography/deposition/etching parameter validation
- Out-of-specification detection
- Tamper detection for recipe/process equipment
- ICS/SCADA protocol awareness using OPC-UA and Modbus
