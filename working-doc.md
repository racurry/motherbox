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

### 1. Create `machines/` and migrate `mini/`

Move `mini/` → `machines/mini/`. Update the hardcoded paths in the launchd plist and any scripts that reference `mini/`. Pure file moves.

### 2. Rename `bin/` → `scripts/`

Move the directory. Rename `run/sync-bin.sh` → `run/sync.sh`. Chase all references in docs, AGENTS.md, common.sh, README, etc.

### 3. Rename SETUP_MODE → PROFILE everywhere

Find every occurrence of `SETUP_MODE`, `setup_mode`, `--mode`, `--reset-mode`, `determine_setup_mode`, `prompt_setup_mode` and replace with the `PROFILE` equivalents. Update the config file key. Update docs and comments. No shims, no fallbacks.

### 4. Teach `run/setup.sh` about machines

Add `--machine` flag. Store `MACHINE` in `~/.config/motherbox/config`. After running profile-aware app setup, run machine-specific setup from `machines/{name}/` if specified.

### 5. Teach `run/maintain.sh` about machines

Machine-specific maintenance (mini's nightly job) becomes invocable through `maintain.sh` instead of a separate `mini.sh` entry point.

### 6. Update docs and AGENTS.md

Reflect the new structure, new naming, new flags. Make sure future agents/contributors know the lay of the land.
