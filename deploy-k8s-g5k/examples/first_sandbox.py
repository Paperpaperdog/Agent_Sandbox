#!/usr/bin/env python3
"""Minimal OpenSandbox SDK example for Grid'5000 control-plane VMs.

Prerequisites on the control plane:
  - OpenSandbox server healthy (port-forward to localhost:8080)
  - python venv with: pip install opensandbox
  - Replace API_KEY with the value stored in opensandbox-server-config
"""

from __future__ import annotations

import asyncio
import os
from datetime import timedelta

from opensandbox import Sandbox
from opensandbox.config import ConnectionConfig
from opensandbox.models import WriteEntry

# Prefer env vars so secrets are not committed.
API_KEY = os.environ.get("OPEN_SANDBOX_API_KEY", "REPLACE_WITH_GENERATED_API_KEY")
DOMAIN = os.environ.get("OPEN_SANDBOX_DOMAIN", "localhost:8080")


async def main() -> None:
    config = ConnectionConfig(
        domain=DOMAIN,
        api_key=API_KEY,
    )

    sandbox = await Sandbox.create(
        "python:3.12-slim",
        connection_config=config,
        timeout=timedelta(minutes=10),
        resource={"cpu": "500m", "memory": "512Mi"},
    )

    try:
        execution = await sandbox.commands.run(
            "echo 'Hello from OpenSandbox on Grid5000!'"
        )
        print(execution.logs.stdout[0].text)

        execution = await sandbox.commands.run("python -c 'print(6 * 7)'")
        print(execution.logs.stdout[0].text)

        await sandbox.files.write_files(
            [
                WriteEntry(
                    path="/tmp/hello.py",
                    data="print('Hola mundo desde el sandbox!')\n",
                    mode=644,
                )
            ]
        )

        execution = await sandbox.commands.run("python /tmp/hello.py")
        print(execution.logs.stdout[0].text)

        content = await sandbox.files.read_file("/tmp/hello.py")
        print(f"File content: {content}")

        print(f"\nSandbox ID: {sandbox.id}")
        print("Inspect with: kubectl get batchsandboxes -n opensandbox")
    finally:
        await sandbox.destroy()
        print("Sandbox destroyed.")


if __name__ == "__main__":
    asyncio.run(main())
