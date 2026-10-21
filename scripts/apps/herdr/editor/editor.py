#!/usr/bin/env python3
"""Launch TTT in a Herdr-owned tab with right-click forwarding."""

import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.parse_args()
    if os.environ.get("HERDR_ENV") != "1":
        parser.error("Run this through the motherbox.ttt Herdr plugin.")
    ttt = shutil.which("ttt")
    if not ttt:
        parser.error("ttt must be installed and available on PATH.")
    herdr = os.environ["HERDR_BIN_PATH"]

    if os.environ.get("HERDR_PLUGIN_ENTRYPOINT_ID") != "editor":
        parser.error("Run this inside the editor plugin pane.")
    # Preserve the invoking project when launched from a palette overlay.
    context = json.loads(os.environ.get("MOTHERBOX_TTT_CONTEXT")
                         or os.environ["HERDR_PLUGIN_CONTEXT_JSON"])
    directory = ((context.get("worktree") or {}).get("checkout_path")
                 or context.get("workspace_cwd")
                 or context.get("focused_pane_cwd"))
    if not directory or not Path(directory).is_dir():
        parser.error("The active Herdr project directory is unavailable.")
    os.chdir(directory)
    for command in [
        ["pane", "input", "--current", "--right-click", "pane"],
        ["tab", "focus", os.environ["HERDR_TAB_ID"]],
        ["plugin", "pane", "focus", os.environ["HERDR_PANE_ID"]],
    ]:
        subprocess.run([herdr, *command], check=True, stdout=subprocess.DEVNULL)
    os.execv(ttt, [ttt, "."])


if __name__ == "__main__":
    main()
