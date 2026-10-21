#!/bin/bash
# Keep Herdr's sidebar and worktrunk's setup in step for git worktrees.
set -euo pipefail

usage() {
    cat <<'EOF'
Usage: worktrees.sh <command> [args]

Keep Herdr's sidebar and worktrunk's setup in step for git worktrees.

Commands:
  open PATH   Open PATH as a workspace grouped under its repo, and focus it.
  close PATH  Close the Herdr workspace open on PATH, if any.
  sync [DIR]  Open every worktree of DIR's repo that Herdr does not show yet.
  created     (plugin event) Open a setup tab in a worktree Herdr just created.
  setup       (plugin pane) Run worktrunk's pre-start and post-start hooks here.

open and close are no-ops outside Herdr, so worktrunk hooks can call them anywhere.
EOF
}

herdr() { "${HERDR_BIN_PATH:-herdr}" "$@"; }

in_herdr() { [[ "${HERDR_ENV:-}" == 1 ]]; }

# Print the herdr worktree entry for PATH as JSON, or nothing.
# Herdr omits open_workspace_id for checkouts it isn't showing.
worktree_entry() {
    local path
    path="$(realpath "$1")"
    herdr worktree list --cwd "$path" \
        | jq -c --arg path "$path" '.result.worktrees[] | select(.path == $path)'
}

open_worktree() {
    local path focus="$2" entry workspace_id repo_root
    path="$(realpath "$1")"
    entry="$(worktree_entry "$path")"
    workspace_id="$(jq -r '.open_workspace_id // empty' <<< "$entry")"
    if [[ -n "$workspace_id" ]]; then
        [[ "$focus" == --focus ]] && herdr workspace focus "$workspace_id" >/dev/null
        return 0
    fi
    # The primary checkout is the group parent; don't adopt it as a child.
    [[ "$(jq -r '.is_linked_worktree' <<< "$entry")" == false ]] && return 0
    repo_root="$(herdr worktree list --cwd "$path" | jq -r '.result.source.repo_root')"
    herdr worktree open --cwd "$repo_root" --path "$path" "$focus" >/dev/null
}

cmd_open() {
    in_herdr || return 0
    open_worktree "$1" --focus
}

cmd_close() {
    in_herdr || return 0
    local workspace_id
    workspace_id="$(worktree_entry "$1" \
        | jq -r 'select(.is_linked_worktree) | .open_workspace_id // empty')"
    [[ -n "$workspace_id" ]] && herdr workspace close "$workspace_id" >/dev/null
    return 0
}

cmd_sync() {
    local directory="${1:-}" path
    if [[ -z "$directory" ]]; then
        directory="$(jq -r '.worktree.checkout_path // .workspace_cwd // .focused_pane_cwd // empty' \
            <<< "${HERDR_PLUGIN_CONTEXT_JSON:-{\}}")"
        [[ -n "$directory" ]] || { echo "No Herdr workspace directory; pass one explicitly." >&2; exit 1; }
    fi
    herdr worktree list --cwd "$directory" | jq -r '.result.worktrees[]
        | select(.is_linked_worktree and (.open_workspace_id | not)
            and (.is_prunable | not) and (.is_bare | not))
        | .path' \
    | while IFS= read -r path; do
        open_worktree "$path" --no-focus
    done
}

cmd_created() {
    local workspace_id path
    workspace_id="$(jq -r '(.data // .).workspace.workspace_id' <<< "$HERDR_PLUGIN_EVENT_JSON")"
    path="$(jq -r '(.data // .).worktree | .checkout_path // .path' <<< "$HERDR_PLUGIN_EVENT_JSON")"
    herdr plugin pane open --plugin motherbox.worktrees --entrypoint setup \
        --placement tab --workspace "$workspace_id" --cwd "$path" --focus >/dev/null
}

cmd_setup() {
    printf 'Running worktrunk setup in %s\n\n' "$PWD"
    local hook
    for hook in pre-start post-start; do
        if ! wt hook "$hook"; then
            read -rp $'\n'"wt hook $hook failed. Press Enter to close."
            exit 1
        fi
    done
}

case "${1:-}" in
    open|close) [[ $# -eq 2 ]] || { usage >&2; exit 2; }; "cmd_$1" "$2" ;;
    sync) cmd_sync "${2:-}" ;;
    created|setup) "cmd_$1" ;;
    -h|--help) usage ;;
    *) usage >&2; exit 2 ;;
esac
