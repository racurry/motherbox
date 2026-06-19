#!/usr/bin/env bats

load '../../lib/bash/common_test_helper.bash'

setup() {
  TEST_TMPDIR="$(mktemp -d)"
  ORIGINAL_HOME="${HOME:-}"
  export HOME="${TEST_TMPDIR}/home"
  mkdir -p "${HOME}"

  CODEX_SCRIPT="${BATS_TEST_DIRNAME}/codex-cli.sh"
}

teardown() {
  rm -rf "${TEST_TMPDIR}"
  if [[ -n "${ORIGINAL_HOME}" ]]; then
    export HOME="${ORIGINAL_HOME}"
  else
    unset HOME
  fi
}

@test "codex.sh creates AGENTS.md symlink" {
  run env HOME="${HOME}" "${CODEX_SCRIPT}" rules
  [ "$status" -eq 0 ]
  [ -L "${HOME}/AGENTS.md" ]
  [ "$(readlink "${HOME}/AGENTS.md")" = "${REPO_ROOT}/apps/_shared/AGENTS.global.md" ]
}

@test "codex.sh is idempotent" {
  env HOME="${HOME}" "${CODEX_SCRIPT}" rules
  run env HOME="${HOME}" "${CODEX_SCRIPT}" rules
  [ "$status" -eq 0 ]
  [ -L "${HOME}/AGENTS.md" ]
}

@test "codex.sh backs up existing AGENTS.md file" {
  echo "existing content" > "${HOME}/AGENTS.md"

  run env HOME="${HOME}" "${CODEX_SCRIPT}" rules
  [ "$status" -eq 0 ]
  [ -L "${HOME}/AGENTS.md" ]
  # Should be backed up to ~/.config/motherbox/backups/YYYYMMDD/shared/
  [ -d "${HOME}/.config/motherbox/backups" ]
  backup_file=$(find "${HOME}/.config/motherbox/backups" -name "AGENTS.md.*" -type f)
  [ -n "$backup_file" ]
}

@test "codex.sh --help shows usage information" {
  run "${CODEX_SCRIPT}" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage:"* ]]
  [[ "$output" == *"Link Codex CLI global configuration"* ]]
  [[ "$output" == *"-h, --help"* ]]
}

@test "codex.sh -h shows usage information" {
  run "${CODEX_SCRIPT}" -h
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage:"* ]]
  [[ "$output" == *"Link Codex CLI global configuration"* ]]
  [[ "$output" == *"-h, --help"* ]]
}

@test "codex.sh with no arguments shows help" {
  run "${CODEX_SCRIPT}"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage:"* ]]
}
