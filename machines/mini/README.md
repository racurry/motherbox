# mini

Scripts for the always-on Mac Mini.  These are specific to only the mini, and not meant to be pushed around elsewhere.

## Setup

This assumes a setup of `run/setup.sh`.

### obsidian-headless

`sync-obsidian.applescript` requires [obsidian-headless](https://www.npmjs.com/package/obsidian-headless) (`ob`).

```bash
npm install -g obsidian-headless
ob login
ob sync-setup --vault Memex --path ~/Notes/Memex
```

## Scripts

- `restart-claude-desktop.applescript` — Quit and relaunch Claude Desktop to trigger an update on relaunch
- `sync-obsidian.applescript` — Quit Obsidian, sync Memex vault headlessly
