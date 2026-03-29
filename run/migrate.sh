#!/bin/bash
set -euo pipefail
shopt -s nullglob

# Migration: ~/workspace → ~/code
# One-time use. Run from anywhere. Delete after.

OLD="${HOME}/workspace"
NEW="${HOME}/code"

log() { printf '  %s\n' "$1"; }
move() {
    log "mv $1 → $2"
    mv "$1" "$2"
}
skip() { log "skip: $1"; }

# ── Preflight ────────────────────────────────────────────────────────

if [[ ! -d "${OLD}" ]]; then
    echo "==> ${OLD} does not exist, skipping"
    exit 0
fi

if [[ -d "${NEW}/me" ]]; then
    echo "==> ${NEW}/me already exists, looks like migration already ran"
    exit 0
fi

echo "==> Creating directory structure"
mkdir -p "${NEW}/me" "${NEW}/me/_archive" "${NEW}/me/_scratch" "${NEW}/vendor"

# ── Delete stale worktrees ───────────────────────────────────────────

echo "==> Removing stale worktrees"
rm -rf "${OLD}/worktrees"
rm -rf "${OLD}/infra/worktrees"

# ── Move infra/ repos (except motherbox) ──────────────────────────────

if [[ -d "${OLD}/infra" ]]; then
    echo "==> Moving infra repos"
    for item in "${OLD}/infra/"*; do
        name="$(basename "$item")"
        case "$name" in
        .DS_Store | .claude | motherbox) skip "$name" ;;
        *) move "$item" "${NEW}/me/${name}" ;;
        esac
    done
else
    echo "==> No infra/ directory, skipping"
fi

# ── Move vendor/ repos ───────────────────────────────────────────────

if [[ -d "${OLD}/vendor" ]]; then
    echo "==> Moving vendor repos"
    for item in "${OLD}/vendor/"*; do
        name="$(basename "$item")"
        case "$name" in
        .DS_Store) skip "$name" ;;
        *) move "$item" "${NEW}/vendor/${name}" ;;
        esac
    done
else
    echo "==> No vendor/ directory, skipping"
fi

# ── Move sandbox/ → _scratch ─────────────────────────────────────────

if [[ -d "${OLD}/sandbox" ]]; then
    echo "==> Moving sandbox repos to _scratch"
    for item in "${OLD}/sandbox/"*; do
        name="$(basename "$item")"
        case "$name" in
        .DS_Store) skip "$name" ;;
        *) move "$item" "${NEW}/me/_scratch/${name}" ;;
        esac
    done
else
    echo "==> No sandbox/ directory, skipping"
fi

# ── Move loose repos from workspace root ──────────────────────────────

echo "==> Moving loose repos"
for item in "${OLD}/"*; do
    name="$(basename "$item")"
    case "$name" in
    .DS_Store | .claude | infra | vendor | sandbox) skip "$name" ;;
    *) move "$item" "${NEW}/me/${name}" ;;
    esac
done

# ── Migrate Claude Code project memory ────────────────────────────────

echo "==> Migrating Claude Code project memory"
CLAUDE_PROJECTS="${HOME}/.claude/projects"
if [[ -d "${CLAUDE_PROJECTS}" ]]; then
    for dir in "${CLAUDE_PROJECTS}/"*workspace*; do
        [[ -d "$dir" ]] || continue
        old_name="$(basename "$dir")"
        new_name="${old_name//workspace/code}"
        new_name="${new_name//-infra/}"
        # workspace root projects → code/me
        new_name="${new_name//-code-/-code-me-}"
        if [[ "$old_name" != "$new_name" ]]; then
            move "$dir" "${CLAUDE_PROJECTS}/${new_name}"
        fi
    done
fi

# ── Cleanup ───────────────────────────────────────────────────────────

echo "==> Checking leftovers"
remaining=$(find "${OLD}" -mindepth 1 -not -name '.DS_Store' | head -5)
if [[ -z "$remaining" ]]; then
    rm -rf "${OLD}"
    log "Removed ${OLD}"
else
    log "${OLD} still has files to clean up manually"
fi

echo ""
echo "==> Done! Everything except motherbox now lives in ${NEW}/"
echo ""
echo "    Next steps:"
echo "      mv ~/workspace/infra/motherbox ~/code/me/motherbox"
echo "      cd ~/code/me/motherbox && ./run/setup.sh"
echo "      rm ~/migrate.sh"
