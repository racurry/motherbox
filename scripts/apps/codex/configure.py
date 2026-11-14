#!/usr/bin/env python3
"""Apply Motherbox's selected Codex settings through its configuration API."""

import argparse
import asyncio
import json
import sys
from pathlib import Path


async def request(process, request_id, method, params):
    message = {"id": request_id, "method": method, "params": params}
    process.stdin.write((json.dumps(message) + "\n").encode())
    await process.stdin.drain()
    while line := await process.stdout.readline():
        response = json.loads(line)
        if response.get("id") == request_id:
            if "error" in response:
                raise RuntimeError(response["error"]["message"])
            return response["result"]
    raise RuntimeError(f"Codex exited before replying to {method}")


async def configure(settings):
    process = await asyncio.create_subprocess_exec(
        "codex", "app-server", "--listen", "stdio://",
        stdin=asyncio.subprocess.PIPE,
        stdout=asyncio.subprocess.PIPE,
    )
    try:
        await request(process, 0, "initialize", {
            "clientInfo": {"name": "motherbox_config", "version": "1.0.0"},
        })
        process.stdin.write(b'{"method":"initialized","params":{}}\n')
        await process.stdin.drain()
        for request_id, (key, value) in enumerate(settings.items(), start=1):
            result = await request(process, request_id, "config/value/write", {
                "keyPath": key,
                "value": value,
                "mergeStrategy": "upsert",
            })
            if result["status"] != "ok":
                raise RuntimeError(f"Codex configuration write for {key} returned {result['status']}")
    finally:
        if process.returncode is None:
            process.terminate()
        try:
            await asyncio.wait_for(process.wait(), timeout=5)
        except TimeoutError:
            process.kill()
            await process.wait()


def main():
    parser = argparse.ArgumentParser(
        description="Apply Codex settings from a JSON object on stdin, preserving other settings.",
        epilog="Keys are dotted Codex config paths. Run through the chezmoi Codex setup hook.",
    )
    parser.parse_args()
    try:
        settings = json.load(sys.stdin)
        if not isinstance(settings, dict) or not settings:
            raise ValueError("stdin must contain a nonempty JSON object of Codex settings")
        if root := settings.get("desktop.git-worktree-root"):
            Path(root).mkdir(parents=True, exist_ok=True)
        asyncio.run(asyncio.wait_for(configure(settings), timeout=30))
    except (OSError, ValueError, RuntimeError, TimeoutError) as error:
        parser.exit(1, f"error: {error}\n")
    print(f"Codex: applied {len(settings)} Motherbox settings")


if __name__ == "__main__":
    main()

