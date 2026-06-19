#!/usr/bin/env bats

load '../../lib/bash/common_test_helper.bash'

setup() {
  TEST_TMPDIR="$(mktemp -d)"
  ORIGINAL_HOME="${HOME:-}"
  export HOME="${TEST_TMPDIR}/home"
  mkdir -p "${HOME}"

  GEMINI_SCRIPT="${BATS_TEST_DIRNAME}/gemini-cli.sh"
}

teardown() {
  rm -rf "${TEST_TMPDIR}"
  if [[ -n "${ORIGINAL_HOME}" ]]; then
    export HOME="${ORIGINAL_HOME}"
  else
    unset HOME
  fi
}

@test "gemini-cli.sh creates AGENTS.md symlink" {
  run env HOME="${HOME}" "${GEMINI_SCRIPT}" rules
  [ "$status" -eq 0 ]
  [ -L "${HOME}/AGENTS.md" ]
  [ "$(readlink "${HOME}/AGENTS.md")" = "${REPO_ROOT}/apps/_shared/AGENTS.global.md" ]
}

@test "gemini-cli.sh is idempotent" {
  env HOME="${HOME}" "${GEMINI_SCRIPT}" rules
  run env HOME="${HOME}" "${GEMINI_SCRIPT}" rules
  [ "$status" -eq 0 ]
  [ -L "${HOME}/AGENTS.md" ]
}

@test "gemini-cli.sh backs up existing AGENTS.md file" {
  echo "existing content" > "${HOME}/AGENTS.md"

  run env HOME="${HOME}" "${GEMINI_SCRIPT}" rules
  [ "$status" -eq 0 ]
  [ -L "${HOME}/AGENTS.md" ]
  # Should be backed up to ~/.config/motherbox/backups/YYYYMMDD/shared/
  [ -d "${HOME}/.config/motherbox/backups" ]
  backup_file=$(find "${HOME}/.config/motherbox/backups" -name "AGENTS.md.*" -type f)
  [ -n "$backup_file" ]
}

@test "gemini-cli.sh --help shows usage information" {
  run "${GEMINI_SCRIPT}" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage:"* ]]
  [[ "$output" == *"Link Gemini CLI global configuration"* ]]
  [[ "$output" == *"-h, --help"* ]]
}

@test "gemini-cli.sh -h shows usage information" {
  run "${GEMINI_SCRIPT}" -h
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage:"* ]]
  [[ "$output" == *"Link Gemini CLI global configuration"* ]]
  [[ "$output" == *"-h, --help"* ]]
}

@test "gemini-cli.sh with no arguments shows help" {
  run "${GEMINI_SCRIPT}"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage:"* ]]
}
