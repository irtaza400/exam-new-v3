"""Topic 127 Phase 3: OPC-UA process-control server.
Simulates nanolithography/deposition/etching equipment variables.
"""
import random
import time
from opcua import Server

ENDPOINT = "opc.tcp://0.0.0.0:4840/topic127/opcua/server/"
NAMESPACE = "urn:topic127:nanomanufacturing"

server = Server()
server.set_endpoint(ENDPOINT)
idx = server.register_namespace(NAMESPACE)

objects = server.get_objects_node()
machine = objects.add_object(idx, "NanoManufacturingMachine")

recipe_id = machine.add_variable(idx, "RecipeID", "RCP-LITHO-001")
process_name = machine.add_variable(idx, "ProcessName", "nanolithography")
temperature_setpoint = machine.add_variable(idx, "TemperatureSetpoint", 22.0)
pressure_setpoint = machine.add_variable(idx, "PressureSetpoint", 1.0)
etch_time = machine.add_variable(idx, "EtchTimeSeconds", 60)
machine_status = machine.add_variable(idx, "MachineStatus", "RUNNING")
security_state = machine.add_variable(idx, "SecurityState", "NORMAL")

for node in [recipe_id, process_name, temperature_setpoint, pressure_setpoint, etch_time, machine_status, security_state]:
    node.set_writable()

server.start()
print(f"OPC-UA server running at {ENDPOINT}")
print("Press CTRL+C to stop.")

try:
    while True:
        process = random.choice(["nanolithography", "deposition", "etching"])
        process_name.set_value(process)
        temperature_setpoint.set_value(round(random.uniform(20, 28), 2))
        pressure_setpoint.set_value(round(random.uniform(0.80, 1.30), 2))
        etch_time.set_value(random.randint(50, 80))
        machine_status.set_value(random.choice(["RUNNING", "RUNNING", "RUNNING", "MAINTENANCE"]))
        security_state.set_value(random.choice(["NORMAL", "NORMAL", "NORMAL", "CHECK_REQUIRED"]))
        time.sleep(3)
except KeyboardInterrupt:
    print("Stopping OPC-UA server...")
finally:
    server.stop()
