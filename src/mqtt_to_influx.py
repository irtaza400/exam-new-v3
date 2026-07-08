import json
import os
from datetime import datetime, timezone
import paho.mqtt.client as mqtt
from influxdb_client import InfluxDBClient, Point, WritePrecision

BROKER = os.getenv("MQTT_BROKER", "localhost")
PORT = int(os.getenv("MQTT_PORT", "1883"))
TOPIC = "topic127/cleanroom/sensors"

INFLUX_URL = os.getenv("INFLUX_URL", "http://localhost:8086")
TOKEN = os.getenv("INFLUX_TOKEN", "topic127-token")
ORG = os.getenv("INFLUX_ORG", "topic127")
BUCKET = os.getenv("INFLUX_BUCKET", "cleanroom")

influx = InfluxDBClient(url=INFLUX_URL, token=TOKEN, org=ORG)
write_api = influx.write_api()


def on_connect(client, userdata, flags, reason_code, properties):
    print("Connected to MQTT broker:", reason_code)
    client.subscribe(TOPIC)


def on_message(client, userdata, msg):
    data = json.loads(msg.payload.decode())

    point = (
        Point("cleanroom_monitoring")
        .tag("zone", data["zone"])
        .tag("machine_id", data["machine_id"])
        .tag("process", data["process"])
        .field("particle_count", float(data["particle_count"]))
        .field("temperature", float(data["temperature"]))
        .field("humidity", float(data["humidity"]))
        .field("airflow", float(data["airflow"]))
        .field("gas_ppm", float(data["gas_ppm"]))
        .field("ppe_compliant", int(bool(data["ppe_compliant"])))
        .time(datetime.now(timezone.utc), WritePrecision.NS)
    )

    write_api.write(bucket=BUCKET, org=ORG, record=point)
    print("Stored in InfluxDB:", data)


def main() -> None:
    client = mqtt.Client(mqtt.CallbackAPIVersion.VERSION2)
    client.on_connect = on_connect
    client.on_message = on_message
    client.connect(BROKER, PORT, 60)
    client.loop_forever()


if __name__ == "__main__":
    main()
