#!/usr/bin/env python3
"""Set Codex's worktree root through its configuration API."""

import argparse
import asyncio
import json
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


async def configure(root):
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
        result = await request(process, 1, "config/value/write", {
            "keyPath": "desktop.git-worktree-root",
            "value": str(root),
            "mergeStrategy": "upsert",
        })
        if result["status"] != "ok":
            raise RuntimeError(f"Codex configuration write returned {result['status']}")
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
        description="Set Codex's worktree root to ~/.worktrees/codex, preserving other settings.",
    )
    parser.parse_args()
    root = Path.home() / ".worktrees" / "codex"
    try:
        root.mkdir(parents=True, exist_ok=True)
        asyncio.run(asyncio.wait_for(configure(root), timeout=30))
    except (OSError, RuntimeError, TimeoutError) as error:
        parser.exit(1, f"error: {error}\n")
    print(f"Codex worktree root: {root}")


if __name__ == "__main__":
    main()

