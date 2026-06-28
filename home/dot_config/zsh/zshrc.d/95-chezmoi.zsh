# Semantic diff of ~/.claude/settings.json vs chezmoi's managed target, with
# keys sorted so the modify_ template's toPrettyJson reordering drops out and
# you see only real changes.
claude-settings-diff() {
    diff <(jq -S . ~/.claude/settings.json) <(chezmoi cat ~/.claude/settings.json | jq -S .)
}
