#!/usr/bin/env -S uv run --quiet --script
# /// script
# requires-python = ">=3.12"
# dependencies = ["tomlkit"]
# ///
"""Apply Motherbox's selected Grok settings in the user config file."""

import argparse
import json
import os
import sys
from pathlib import Path

import tomlkit
from tomlkit.exceptions import TOMLKitError
from tomlkit.items import InlineTable, Table
from tomlkit.toml_document import TOMLDocument

MISSING = object()
# TOMLDocument is the parsed file and is not a Table subclass.
TABLES = (Table, InlineTable, TOMLDocument)


def main():
    parser = argparse.ArgumentParser(
        description="Apply Grok settings from a JSON object on stdin, preserving other settings.",
        epilog="Keys are dotted paths. A JSON null removes that key. Run through the chezmoi Grok setup hook.",
    )
    parser.add_argument(
        "--config",
        type=Path,
        help="config file to update (default: $GROK_HOME/config.toml or ~/.grok/config.toml)",
    )
    args = parser.parse_args()
    try:
        settings = json.load(sys.stdin)
        if not isinstance(settings, dict) or not settings:
            raise ValueError("stdin must contain a nonempty JSON object of Grok settings")
        apply_settings(config_path(args.config), settings)
    except (OSError, ValueError, TOMLKitError) as error:
        parser.exit(1, f"error: {error}\n")
    print(f"Grok: applied {len(settings)} Motherbox settings")


def config_path(explicit):
    if explicit is not None:
        return explicit
    root = os.environ.get("GROK_HOME")
    base = Path(root) if root else Path.home() / ".grok"
    return base / "config.toml"


def apply_settings(path, settings):
    for key in settings:
        if not isinstance(key, str) or not key or any(part == "" for part in key.split(".")):
            raise ValueError(f"invalid key path {key!r}")
    document, existed = load_document(path)
    if not needs_change(document, settings):
        return
    for key, value in settings.items():
        if value is None:
            delete_path(document, key.split("."))
        else:
            set_path(document, key, value)
    save_document(path, document, create=not existed)


def load_document(path):
    if not path.exists() and not path.is_symlink():
        return tomlkit.document(), False
    if path.is_symlink() and not path.resolve().is_file():
        raise ValueError(f"{path} is a dangling symlink")
    if not path.is_file():
        raise ValueError(f"{path} is not a file")
    try:
        return tomlkit.parse(path.read_text()), True
    except TOMLKitError as error:
        raise ValueError(f"{path} is not valid TOML: {error}") from error


def needs_change(document, settings):
    for key, value in settings.items():
        current = get_path(document, key.split("."))
        if value is None:
            if current is not MISSING:
                return True
            continue
        if current is MISSING or unwrap(current) != value:
            return True
    return False


def get_path(node, parts):
    for part in parts:
        if not isinstance(node, TABLES):
            return MISSING
        try:
            node = node[part]
        except KeyError:
            return MISSING
    return node


def unwrap(value):
    return value.unwrap() if hasattr(value, "unwrap") else value


def set_path(document, dotted, value):
    node = document
    parts = dotted.split(".")
    for part in parts[:-1]:
        if part not in node:
            node[part] = tomlkit.table()
        child = node[part]
        if not isinstance(child, TABLES):
            raise ValueError(f"{dotted}: {part!r} exists and is not a table")
        node = child
    node[parts[-1]] = toml_value(value)


def toml_value(value):
    if isinstance(value, dict):
        table = tomlkit.table()
        for key, item in value.items():
            if not isinstance(key, str) or not key:
                raise ValueError("JSON object keys must be nonempty strings")
            table[key] = toml_value(item)
        return table
    if isinstance(value, list):
        array = tomlkit.array()
        for item in value:
            array.append(toml_value(item))
        return array
    if isinstance(value, (str, int, float, bool)):
        return value
    raise ValueError(f"unsupported JSON value {value!r}")


def delete_path(document, parts):
    parents = [document]
    node = document
    for part in parts[:-1]:
        if not isinstance(node, TABLES) or part not in node:
            return
        node = node[part]
        parents.append(node)
    leaf = parts[-1]
    if not isinstance(node, TABLES) or leaf not in node:
        return
    del node[leaf]
    for index in range(len(parts) - 2, -1, -1):
        child = parents[index + 1]
        if len(child) != 0:
            return
        del parents[index][parts[index]]


def save_document(path, document, create):
    target = path.resolve() if path.is_symlink() else path
    if not create and not target.is_file():
        raise ValueError(f"{path} is not a file")
    target.parent.mkdir(parents=True, exist_ok=True)
    text = tomlkit.dumps(document)
    if not text.endswith("\n"):
        text += "\n"
    temporary = target.with_name(f".{target.name}.{os.getpid()}.tmp")
    try:
        temporary.write_text(text)
        os.replace(temporary, target)
    finally:
        if temporary.exists():
            temporary.unlink()


if __name__ == "__main__":
    main()
