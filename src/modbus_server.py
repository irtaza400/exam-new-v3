"""Topic 127 Phase 3: Modbus TCP PLC/register simulator."""
import asyncio
import random
from pymodbus.datastore import ModbusServerContext, ModbusSlaveContext, ModbusSequentialDataBlock
from pymodbus.server import StartAsyncTcpServer

store = ModbusSlaveContext(hr=ModbusSequentialDataBlock(0, [0] * 100))
context = ModbusServerContext(slaves=store, single=True)


async def update_registers():
    while True:
        # Holding register meanings:
        # 0 = motor speed RPM
        # 1 = valve status 0/1
        # 2 = chamber pressure scaled integer
        # 3 = alarm code
        # 4 = recipe lock status 1 locked, 0 unlocked
        values = [
            random.randint(800, 1500),
            random.randint(0, 1),
            random.randint(80, 130),
            random.choice([0, 0, 0, 5]),
            random.choice([1, 1, 1, 0]),
        ]
        context[0].setValues(3, 0, values)
        print("Updated Modbus holding registers:", values)
        await asyncio.sleep(3)


async def main():
    asyncio.create_task(update_registers())
    print("Modbus TCP server running on 0.0.0.0:5020")
    await StartAsyncTcpServer(context=context, address=("0.0.0.0", 5020))


if __name__ == "__main__":
    asyncio.run(main())
