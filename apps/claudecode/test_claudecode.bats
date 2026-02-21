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
  grep -q 'enforce-relative-paths' "${HOME}/.claude/settings.json"
}

@test "enforce-relative-paths.sh blocks fully qualified cwd paths" {
  local hook="${BATS_TEST_DIRNAME}/hooks/enforce-relative-paths.sh"
  local testdir="${TEST_TMPDIR}/fakecwd"
  mkdir -p "$testdir"
  run bash -c "cd '$testdir' && echo '{\"tool_input\":{\"command\":\"python ${testdir}/script.py\"}}' | '$hook'"
  [ "$status" -eq 2 ]
  [[ "$output" == *"relative paths"* ]]
}

@test "enforce-relative-paths.sh allows relative paths" {
  local hook="${BATS_TEST_DIRNAME}/hooks/enforce-relative-paths.sh"
  run bash -c "echo '{\"tool_input\":{\"command\":\"python ./script.py\"}}' | '$hook'"
  [ "$status" -eq 0 ]
}

@test "enforce-relative-paths.sh allows paths outside cwd" {
  local hook="${BATS_TEST_DIRNAME}/hooks/enforce-relative-paths.sh"
  local testdir="${TEST_TMPDIR}/fakecwd"
  mkdir -p "$testdir"
  run bash -c "cd '$testdir' && echo '{\"tool_input\":{\"command\":\"python /usr/local/bin/something\"}}' | '$hook'"
  [ "$status" -eq 0 ]
}

@test "enforce-relative-paths.sh allows docker commands with absolute paths" {
  local hook="${BATS_TEST_DIRNAME}/hooks/enforce-relative-paths.sh"
  local testdir="${TEST_TMPDIR}/fakecwd"
  mkdir -p "$testdir"
  run bash -c "cd '$testdir' && echo '{\"tool_input\":{\"command\":\"docker run -v ${testdir}/data:/data img\"}}' | '$hook'"
  [ "$status" -eq 0 ]
}

@test "enforce-relative-paths.sh allows docker-compose with absolute paths" {
  local hook="${BATS_TEST_DIRNAME}/hooks/enforce-relative-paths.sh"
  local testdir="${TEST_TMPDIR}/fakecwd"
  mkdir -p "$testdir"
  run bash -c "cd '$testdir' && echo '{\"tool_input\":{\"command\":\"docker-compose -f ${testdir}/docker-compose.yml up\"}}' | '$hook'"
  [ "$status" -eq 0 ]
}

@test "enforce-relative-paths.sh ignores cwd path in description field" {
  local hook="${BATS_TEST_DIRNAME}/hooks/enforce-relative-paths.sh"
  local testdir="${TEST_TMPDIR}/fakecwd"
  mkdir -p "$testdir"
  run bash -c "cd '$testdir' && echo '{\"tool_input\":{\"command\":\"python ./script.py\",\"description\":\"Run script in ${testdir}\"}}' | '$hook'"
  [ "$status" -eq 0 ]
}
