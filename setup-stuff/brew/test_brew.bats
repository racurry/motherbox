#!/usr/bin/env bats

load '../../lib/bash/common_test_helper.bash'

setup() {
  TEST_TMPDIR="$(mktemp -d)"
}

teardown() {
  rm -rf "${TEST_TMPDIR}"
}

@test "brew.sh install succeeds when brew is available in PATH" {
  # Skip this test if we don't have curl
  if ! command -v curl >/dev/null 2>&1; then
    skip "curl command not available"
  fi


  # Create mock brew command that reports it's already installed
  mkdir -p "${TEST_TMPDIR}/bin"
  ln -s "$(command -v true)" "${TEST_TMPDIR}/bin/brew"
  export PATH="${TEST_TMPDIR}/bin:${PATH}"

  run bash "${BATS_TEST_DIRNAME}/brew.sh" install
  [ "$status" -eq 0 ]
  [[ "$output" == *"Homebrew already installed"* ]]
}

@test "brew.sh shows help when --help is passed" {
  run bash "${BATS_TEST_DIRNAME}/brew.sh" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage:"* ]]
  [[ "$output" == *"install"* ]]
  [[ "$output" == *"bundle"* ]]
}

@test "brew.sh shows error for unknown argument" {
  run bash "${BATS_TEST_DIRNAME}/brew.sh" unknown
  [ "$status" -eq 0 ]
  [[ "$output" == *"Ignoring unknown argument"* ]]
}

@test "brew.sh bundle requires brew command" {

  # Remove brew from PATH if it exists
  export PATH="$(echo "$PATH" | tr ':' '\n' | grep -v brew | tr '\n' ':')"

  run bash "${BATS_TEST_DIRNAME}/brew.sh" bundle
  [ "$status" -ne 0 ]
}

@test "brew.sh maintain requires brew command" {

  # Remove brew from PATH if it exists
  export PATH="$(echo "$PATH" | tr ':' '\n' | grep -v brew | tr '\n' ':')"

  run bash "${BATS_TEST_DIRNAME}/brew.sh" maintain
  [ "$status" -ne 0 ]
}

@test "brew.sh help includes maintain command" {
  run bash "${BATS_TEST_DIRNAME}/brew.sh" help
  [ "$status" -eq 0 ]
  [[ "$output" == *"maintain"* ]]
}