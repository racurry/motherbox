#!/usr/bin/env bats

load '../../lib/bash/common_test_helper.bash'

setup() {
  TEST_TMPDIR="$(mktemp -d)"
  ORIGINAL_HOME="${HOME:-}"
  export HOME="${TEST_TMPDIR}/home"
  mkdir -p "${HOME}"

  CLAUDECODE_SCRIPT="${BATS_TEST_DIRNAME}/claudecode.sh"
}

teardown() {
  rm -rf "${TEST_TMPDIR}"
  if [[ -n "${ORIGINAL_HOME}" ]]; then
    export HOME="${ORIGINAL_HOME}"
  else
    unset HOME
  fi
}

@test "claudecode.sh creates CLAUDE.md symlink" {
  run env HOME="${HOME}" "${CLAUDECODE_SCRIPT}" rules
  [ "$status" -eq 0 ]
  [ -L "${HOME}/.claude/CLAUDE.md" ]
  [ "$(readlink "${HOME}/.claude/CLAUDE.md")" = "${REPO_ROOT}/apps/claudecode/CLAUDE.global.md" ]
}

@test "claudecode.sh creates AGENTS.md symlink to shared location" {
  run env HOME="${HOME}" "${CLAUDECODE_SCRIPT}" rules
  [ "$status" -eq 0 ]
  [ -L "${HOME}/AGENTS.md" ]
  [ "$(readlink "${HOME}/AGENTS.md")" = "${REPO_ROOT}/apps/_shared/AGENTS.global.md" ]
}

@test "claudecode.sh creates settings.json with required fields" {
  run env HOME="${HOME}" "${CLAUDECODE_SCRIPT}" settings
  [ "$status" -eq 0 ]
  [ -f "${HOME}/.claude/settings.json" ]
  grep -q '"alwaysThinkingEnabled": true' "${HOME}/.claude/settings.json"
  grep -q '"enableAllProjectMcpServers": true' "${HOME}/.claude/settings.json"
}

@test "claudecode.sh is idempotent" {
  env HOME="${HOME}" "${CLAUDECODE_SCRIPT}" rules
  env HOME="${HOME}" "${CLAUDECODE_SCRIPT}" settings
  run env HOME="${HOME}" "${CLAUDECODE_SCRIPT}" rules
  [ "$status" -eq 0 ]
  run env HOME="${HOME}" "${CLAUDECODE_SCRIPT}" settings
  [ "$status" -eq 0 ]
  [ -L "${HOME}/.claude/CLAUDE.md" ]
  [ -f "${HOME}/.claude/settings.json" ]
}

@test "claudecode.sh backs up existing CLAUDE.md file" {
  mkdir -p "${HOME}/.claude"
  echo "existing content" > "${HOME}/.claude/CLAUDE.md"

  run env HOME="${HOME}" "${CLAUDECODE_SCRIPT}" rules
  [ "$status" -eq 0 ]
  [ -L "${HOME}/.claude/CLAUDE.md" ]
  # Should be backed up to ~/.config/motherbox/backups/YYYYMMDD/claudecode/
  [ -d "${HOME}/.config/motherbox/backups" ]
  backup_file=$(find "${HOME}/.config/motherbox/backups" -name "CLAUDE.md.*" -type f)
  [ -n "$backup_file" ]
}

@test "claudecode.sh --help shows usage information" {
  run "${CLAUDECODE_SCRIPT}" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage:"* ]]
  [[ "$output" == *"Link Claude Code global configuration"* ]]
  [[ "$output" == *"-h, --help"* ]]
}

@test "claudecode.sh -h shows usage information" {
  run "${CLAUDECODE_SCRIPT}" -h
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage:"* ]]
  [[ "$output" == *"Link Claude Code global configuration"* ]]
  [[ "$output" == *"-h, --help"* ]]
}

@test "claudecode.sh with unknown argument shows warning and help" {
  run "${CLAUDECODE_SCRIPT}" --invalid-option
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage:"* ]]
}

@test "claudecode.sh syncs hooks to ~/.claude/hooks" {
  run env HOME="${HOME}" "${CLAUDECODE_SCRIPT}" hooks
  [ "$status" -eq 0 ]
  [ -L "${HOME}/.claude/hooks/enforce-local-tmp.sh" ]
  [ -x "${HOME}/.claude/hooks/enforce-local-tmp.sh" ]
}

@test "claudecode.sh settings includes PreToolUse hooks" {
  run env HOME="${HOME}" "${CLAUDECODE_SCRIPT}" settings
  [ "$status" -eq 0 ]
  grep -q 'PreToolUse' "${HOME}/.claude/settings.json"
  grep -q 'enforce-local-tmp' "${HOME}/.claude/settings.json"
}

@test "claudecode.sh dereff copies ~/.claude with symlinks dereferenced" {
  # Set up a fake ~/.claude with a real file, a symlink to a file, and a
  # symlink to a directory.
  mkdir -p "${HOME}/.claude/commands"
  echo "real content" > "${HOME}/.claude/CLAUDE.md"

  mkdir -p "${TEST_TMPDIR}/external"
  echo "linked file content" > "${TEST_TMPDIR}/external/linked.md"
  ln -s "${TEST_TMPDIR}/external/linked.md" "${HOME}/.claude/commands/linked.md"

  mkdir -p "${TEST_TMPDIR}/external-dir"
  echo "in linked dir" > "${TEST_TMPDIR}/external-dir/inside.txt"
  ln -s "${TEST_TMPDIR}/external-dir" "${HOME}/.claude/external-dir"

  run env HOME="${HOME}" "${CLAUDECODE_SCRIPT}" dereff
  [ "$status" -eq 0 ]

  # Destination exists
  [ -d "${HOME}/.claude-dereffed" ]

  # Real file is copied
  [ -f "${HOME}/.claude-dereffed/CLAUDE.md" ]
  [ ! -L "${HOME}/.claude-dereffed/CLAUDE.md" ]
  grep -q "real content" "${HOME}/.claude-dereffed/CLAUDE.md"

  # Symlinked file became a real file with the target's contents
  [ -f "${HOME}/.claude-dereffed/commands/linked.md" ]
  [ ! -L "${HOME}/.claude-dereffed/commands/linked.md" ]
  grep -q "linked file content" "${HOME}/.claude-dereffed/commands/linked.md"

  # Symlinked directory became a real directory with its contents copied in
  [ -d "${HOME}/.claude-dereffed/external-dir" ]
  [ ! -L "${HOME}/.claude-dereffed/external-dir" ]
  [ -f "${HOME}/.claude-dereffed/external-dir/inside.txt" ]
  grep -q "in linked dir" "${HOME}/.claude-dereffed/external-dir/inside.txt"
}

@test "claudecode.sh dereff replaces existing destination" {
  mkdir -p "${HOME}/.claude"
  echo "new" > "${HOME}/.claude/marker.txt"

  mkdir -p "${HOME}/.claude-dereffed"
  echo "stale" > "${HOME}/.claude-dereffed/old.txt"

  run env HOME="${HOME}" "${CLAUDECODE_SCRIPT}" dereff
  [ "$status" -eq 0 ]

  [ -f "${HOME}/.claude-dereffed/marker.txt" ]
  [ ! -f "${HOME}/.claude-dereffed/old.txt" ]
}

@test "claudecode.sh dereff fails when ~/.claude is missing" {
  run env HOME="${HOME}" "${CLAUDECODE_SCRIPT}" dereff
  [ "$status" -ne 0 ]
}
