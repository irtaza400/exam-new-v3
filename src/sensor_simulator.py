import json
import random
import time
from datetime import datetime, timezone

import paho.mqtt.client as mqtt


BROKER = "localhost"
PORT = 1883
TOPIC = "topic127/cleanroom/sensors"
PUBLISH_INTERVAL_SECONDS = 2
ABNORMAL_EVENT_PROBABILITY = 0.25


MACHINE_CONFIG = {
    "EQP-100": {
        "zone": "Lithography",
        "process": "nanolithography",
    },
    "EQP-200": {
        "zone": "Deposition",
        "process": "deposition",
    },
    "EQP-300": {
        "zone": "Etching",
        "process": "etching",
    },
}


def create_mqtt_client() -> mqtt.Client:
    client = mqtt.Client(mqtt.CallbackAPIVersion.VERSION2)
    client.connect(BROKER, PORT, 60)
    return client


def generate_sensor_values(abnormal: bool) -> dict:
    if abnormal:
        return {
            "particle_count": random.randint(900, 1800),
            "temperature": round(random.uniform(26.5, 31.0), 2),
            "humidity": round(random.uniform(56.0, 70.0), 2),
            "airflow": round(random.uniform(0.18, 0.29), 2),
            "gas_ppm": round(random.uniform(55.0, 90.0), 2),
            "ppe_compliant": random.choice([True, False]),
        }

    return {
        "particle_count": random.randint(100, 650),
        "temperature": round(random.uniform(20.0, 25.0), 2),
        "humidity": round(random.uniform(35.0, 52.0), 2),
        "airflow": round(random.uniform(0.35, 0.75), 2),
        "gas_ppm": round(random.uniform(0.0, 35.0), 2),
        "ppe_compliant": True,
    }


def sensor_payload() -> dict:
    machine_id = random.choice(list(MACHINE_CONFIG))
    machine_config = MACHINE_CONFIG[machine_id]
    abnormal = random.random() < ABNORMAL_EVENT_PROBABILITY
    sensor_values = generate_sensor_values(abnormal)

    return {
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "machine_id": machine_id,
        "zone": machine_config["zone"],
        "process": machine_config["process"],
        "event_status": "abnormal" if abnormal else "normal",
        **sensor_values,
    }


def main() -> None:
    client = create_mqtt_client()

    print("Cleanroom sensor simulator started.")
    print(f"MQTT broker: {BROKER}:{PORT}")
    print(f"MQTT topic : {TOPIC}")
    print(f"Interval   : {PUBLISH_INTERVAL_SECONDS} seconds")
    print("Machine mappings:")

    for machine_id, config in MACHINE_CONFIG.items():
        print(
            f"  {machine_id} -> "
            f"{config['zone']} -> {config['process']}"
        )

    try:
        while True:
            payload = sensor_payload()
            result = client.publish(TOPIC, json.dumps(payload))

            if result.rc != mqtt.MQTT_ERR_SUCCESS:
                print(
                    "WARNING: MQTT publish failed with result code:",
                    result.rc,
                )
            else:
                print("Published:", payload)

            time.sleep(PUBLISH_INTERVAL_SECONDS)

    except KeyboardInterrupt:
        print("\nSensor simulator stopped by user.")

    finally:
        client.disconnect()


if __name__ == "__main__":
    main()