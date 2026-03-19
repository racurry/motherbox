# What is motherbox?

This repo is a handful of convenience tools, re-usable configs, used for the management of my computer. It manages various things. I manages those things in different context.

## Management of stuff

### profiles

There are specific setup needs, maintenance needs, tools, and other things for me in different contexts of me-as-a-person. Personal life, Galileo life, soon to be others. Those different mes requires different tools.

### machines

The different mes sometimes have the same kind of me, but on a different mac. That is what @mini/ is reflecting. This is a `personal` profile, but not my default machine. This is the `mini` machine. I might want to set up a `personal-laptop` machine. Or a `kids-imac`. I might get a `galileo-desktop` or something.

## motherbox itself

There are scripts (in @run) that are used to manage this repo, and the things inside of it. Setting up and maintaing a machine, testing the scripts I have, linking things to and fro.

## The Stuff that gets managed

### apps

Everything in @apps defines specific applications. How I install and configure them. It is a full library that is profile-aware; it is not currently machine aware.

### scripts

@bin has utilities that I can use as I wish. They are treated like apps, stuffed onto the path of whatever machine I am on. There is no context awareness at all.

______________________________________________________________________

# Restructure Plan

## Target structure

```
motherbox/
├── apps/                   # App catalog (unchanged, profile-aware)
├── machines/               # Machine-specific automation (NEW)
│   ├── mini/
│   └── ...
├── scripts/                # Standalone utilities on PATH (renamed from bin/)
├── lib/                    # Shared infrastructure (unchanged)
├── run/                    # Orchestration verbs (unchanged)
│   ├── setup.sh
│   ├── maintain.sh
│   ├── test.sh
│   └── sync.sh            # renamed from sync-bin.sh
└── docs/
```

## Naming convention: PROFILE replaces SETUP_MODE

Everywhere in the codebase, `SETUP_MODE` becomes `PROFILE`. No backwards compatibility. Config key, CLI flags, env vars, function names, docs — all of it.

- `--mode` flag → `--profile`
- `SETUP_MODE` config key → `PROFILE`
- `determine_setup_mode` → `determine_profile`
- `prompt_setup_mode` → `prompt_profile`
- `--reset-mode` → `--reset-profile`

## Work chunks (in order)

### 1. Create `machines/` and migrate `mini/` — DONE

Moved `mini/` → `machines/mini/`. Replaced static plist with `.plist.template` — `mini.sh setup` generates plist at install time via `sed` so paths aren't hardcoded to a specific user.

### 2. Rename `bin/` → `scripts/` — DONE

Moved directory, renamed `run/sync-bin.sh` → `run/sync.sh`, updated symlink path to `~/.config/motherbox/scripts`, chased all references across docs, AGENTS.md, zsh PATH, plist template, migration plans.

### 3. Rename SETUP_MODE → PROFILE everywhere — DONE

Replaced all occurrences: config key, CLI flags (`--mode` → `--profile`, `--reset-mode` → `--reset-profile`), function names (`determine_setup_mode` → `determine_profile`, `prompt_setup_mode` → `prompt_profile`), global var, docs, tests. No backwards compatibility.

### 4. Teach `run/setup.sh` about machines — DONE

Added `--machine` flag and `determine_machine()` in common.sh. Machine is optional (no prompt), sticky via config. After app setup, runs `machines/{name}/{name}.sh setup` if set.

### 5. Teach `run/maintain.sh` about machines — DONE

Added `maintain.sh machine [args]` command. Reads `MACHINE` from config, delegates to `machines/{name}/{name}.sh maintain [args]`. Example: `maintain.sh machine nightly` runs mini's nightly maintenance.

### 6. Update docs and AGENTS.md — DONE

Updated AGENTS.md core structure (scripts/, machines/, run/ entries), README.md, run/README.md, docs/common config keys, docs/apps bash scripting guide, apps-bash-scripter agent. All incremental during steps 1-5.
