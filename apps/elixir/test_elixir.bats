#!/usr/bin/env bats

load '../../lib/bash/common_test_helper.bash'

setup() {
  TEST_TMPDIR="$(mktemp -d)"
  TEST_HOME="${TEST_TMPDIR}/home"
  TEST_REPO_ROOT="${TEST_TMPDIR}/repo"

  mkdir -p "${TEST_HOME}"
  mkdir -p "${TEST_REPO_ROOT}"

  ORIGINAL_HOME="${HOME:-}"
  ORIGINAL_REPO_ROOT="${REPO_ROOT:-}"

  export HOME="${TEST_HOME}"
  export REPO_ROOT="${TEST_REPO_ROOT}"

  SCRIPT_PATH="${BATS_TEST_DIRNAME}/elixir.sh"
}

teardown() {
  rm -rf "${TEST_TMPDIR}"
  if [[ -n "${ORIGINAL_HOME}" ]]; then
    export HOME="${ORIGINAL_HOME}"
  else
    unset HOME
  fi
  if [[ -n "${ORIGINAL_REPO_ROOT}" ]]; then
    export REPO_ROOT="${ORIGINAL_REPO_ROOT}"
  else
    unset REPO_ROOT
  fi
}

@test "elixir.sh shows help with no arguments" {
  run bash "${SCRIPT_PATH}"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage:"* ]]
  [[ "$output" == *"setup"* ]]
}

@test "elixir.sh --help shows usage information" {
  run bash "${SCRIPT_PATH}" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage:"* ]]
  [[ "$output" == *"Set up Elixir and Phoenix"* ]]
  [[ "$output" == *"-h, --help"* ]]
}

@test "elixir.sh -h shows usage information" {
  run bash "${SCRIPT_PATH}" -h
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage:"* ]]
}

@test "elixir.sh setup fails when mix is not installed" {
  create_minimal_path "${TEST_TMPDIR}" "mix"

  run env PATH="${TEST_TMPDIR}/bin" HOME="${HOME}" REPO_ROOT="${REPO_ROOT}" bash "${SCRIPT_PATH}" setup
  [ "$status" -eq 1 ]
  [[ "$output" == *"Required command 'mix' not found in PATH"* ]]
}

@test "elixir.sh setup runs mix archive.install with correct args" {
  # Set up minimal PATH first, then add mock mix command
  create_minimal_path "${TEST_TMPDIR}" ""

  cat > "${TEST_TMPDIR}/bin/mix" << 'MOCK'
#!/bin/bash
echo "mix $*"
exit 0
MOCK
  chmod +x "${TEST_TMPDIR}/bin/mix"

  run env PATH="${TEST_TMPDIR}/bin" HOME="${HOME}" REPO_ROOT="${REPO_ROOT}" bash "${SCRIPT_PATH}" setup
  [ "$status" -eq 0 ]
  [[ "$output" == *"mix archive.install hex phx_new --force"* ]]
}
