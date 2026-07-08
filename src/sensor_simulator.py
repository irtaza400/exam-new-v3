import json
import random
import time
from datetime import datetime, timezone
import paho.mqtt.client as mqtt

BROKER = "localhost"
PORT = 1883
TOPIC = "topic127/cleanroom/sensors"

client = mqtt.Client(mqtt.CallbackAPIVersion.VERSION2)
client.connect(BROKER, PORT, 60)

ZONES = ["Lithography", "Deposition", "Etching", "Packaging"]
PROCESSES = ["nanolithography", "deposition", "etching"]
MACHINES = ["EQP-100", "EQP-200", "EQP-300"]


def sensor_payload() -> dict:
    # Mostly normal readings, sometimes abnormal readings for exam demo.
    abnormal = random.random() < 0.25
    if abnormal:
        particle_count = random.randint(900, 1800)
        temperature = random.uniform(26.5, 31.0)
        humidity = random.uniform(56, 70)
        airflow = random.uniform(0.18, 0.29)
        gas_ppm = random.uniform(55, 90)
        ppe_compliant = random.choice([True, False])
    else:
        particle_count = random.randint(100, 650)
        temperature = random.uniform(20, 25)
        humidity = random.uniform(35, 52)
        airflow = random.uniform(0.35, 0.75)
        gas_ppm = random.uniform(0, 35)
        ppe_compliant = True

    return {
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "zone": random.choice(ZONES),
        "process": random.choice(PROCESSES),
        "machine_id": random.choice(MACHINES),
        "particle_count": particle_count,
        "temperature": round(temperature, 2),
        "humidity": round(humidity, 2),
        "airflow": round(airflow, 2),
        "gas_ppm": round(gas_ppm, 2),
        "ppe_compliant": ppe_compliant,
    }


def main() -> None:
    print(f"Publishing simulated cleanroom sensor events to MQTT topic: {TOPIC}")
    while True:
        payload = sensor_payload()
        client.publish(TOPIC, json.dumps(payload))
        print("Published:", payload)
        time.sleep(2)


if __name__ == "__main__":
    main()
