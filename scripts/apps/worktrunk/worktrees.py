#!/usr/bin/env python3
"""Report worktree status or clean up finished work against the local default branch."""

import argparse
import json
import subprocess
import sys


def git(path, *args):
    return subprocess.check_output(["git", "-C", path, *args])


def branch_status(item, base):
    branch = item["branch"]
    comparison = item.get("default_branch") or {}
    integration = (comparison.get("integration") or {}).get("reason")
    if integration == "same_commit":
        reason = f"matches {base}"
    elif integration == "ancestor":
        reason = f"already in {base}"
    elif integration in ("trees_match", "merge_adds_nothing", "patch_id_match", "no_added_changes"):
        reason = f"all changes accounted for in {base}"
    elif comparison.get("ahead", 0) > 0 or comparison.get("orphan"):
        return "Keep", "In progress", f"work outside {base}"
    else:
        return "Review", "—", f"could not verify integration with {base}"

    # Integration alone also matches unused branches, including a branch created
    # from an old squash-merged tip. Require evidence of work on this branch.
    history = git(".", "reflog", "show", "--format=%gs", f"refs/heads/{branch}").splitlines()
    if len(history) == 1 and history[0].startswith(b"branch: Created from "):
        return "Keep", "Brand new", reason
    if any(line.startswith((b"commit", b"cherry-pick")) for line in history):
        return "Delete OK", "Done", reason
    return "Keep", "New or done", reason


def assess(item, base):
    tree = item["worktree"]
    branch = item.get("branch")
    path = tree["path"]
    if tree["main"] or branch == base:
        return "Keep", "Primary", "primary checkout" if tree["main"] else "default branch"
    if "locked" in tree or "prunable" in tree or tree.get("duplicate_branch"):
        return "Review", "—", "locked, missing, or shared checkout"
    if tree.get("operation"):
        return "Keep", "In progress", f"{tree['operation']} in progress"
    if tree["detached"] or not branch:
        return "Review", "—", "detached checkout"

    # Override repository preferences that can hide untracked files or dirty submodules.
    status = git(path, "status", "--porcelain=v1", "-z", "--untracked-files=normal",
                 "--ignore-submodules=none", "--ignored=matching").split(b"\0")
    if any(entry and not entry.startswith(b"!! ") for entry in status):
        reason = "untracked files" if all(entry[:2] in (b"??", b"!!", b"") for entry in status) else "uncommitted changes"
        return "Keep", "In progress", reason

    decision, stage, reason = branch_status(item, base)
    if decision == "Delete OK" and any(entry.startswith(b"!! ") for entry in status):
        return "Review", stage, "ignored files would be deleted"
    return decision, stage, reason


def main():
    parser = argparse.ArgumentParser(prog="wt", description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    commands.add_parser("status", help="Show which worktrees cleanup would remove.")
    cleanup = commands.add_parser("cleanup", help="Remove finished worktrees and branches.")
    cleanup.add_argument("--preview", action="store_true", help="Print the names selected for removal.")
    cleanup.add_argument("--format", choices=("text", "json"), help="Worktrunk removal output format.")
    cleanup.add_argument("--foreground", action="store_true", help=argparse.SUPPRESS)
    for flag in ("--no-delete-branch", "--delete-branch", "--no-hooks",
                 "--reap", "--yes", "-y", "--force", "-f", "--force-delete", "-D"):
        cleanup.add_argument(flag, action="append_const", dest="remove_flags", const=flag,
                             help=argparse.SUPPRESS)
    args = parser.parse_args()
    cleaning = args.command == "cleanup"
    listing = ["wt", "--config-set", "list.json-schema=2", "list", "--format=json"]
    if cleaning:
        listing.append("--branches")
    report = json.loads(subprocess.check_output(listing))
    base = report["repo"]["default_branch"]
    rows = [("Worktree", "Decision", "Stage", f"Reason (local {base})")]
    candidates = []
    for item in report["items"]:
        tree = item.get("worktree")
        branch = item.get("branch")
        try:
            if tree:
                result = assess(item, base)
                rows.append((branch or tree["path"], *result))
            elif cleaning and branch and branch != base and not item.get("remote"):
                result = branch_status(item, base)
            else:
                continue
        except (OSError, subprocess.CalledProcessError):
            if tree:
                rows.append((branch or tree["path"], "Review", "—", "could not inspect checkout"))
            continue
        if result[0] == "Delete OK":
            candidates.append(branch)

    if cleaning:
        if not candidates:
            print("Nothing to clean up.")
        elif args.preview:
            print(*candidates, sep="\n")
        else:
            flags = args.remove_flags or []
            if args.format:
                flags += ["--format", args.format]
            subprocess.run(["wt", "remove", "--foreground", *flags, "--", *candidates], check=True)
        return

    widths = [max(map(len, column)) for column in zip(*rows)]
    for row in rows:
        print("  ".join(cell.ljust(width) for cell, width in zip(row, widths)).rstrip())


if __name__ == "__main__":
    try:
        main()
    except subprocess.CalledProcessError as error:
        sys.exit(error.returncode)
