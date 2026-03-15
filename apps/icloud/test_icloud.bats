#!/usr/bin/env bats

setup() {
  TEST_TMPDIR="$(mktemp -d)"
  ORIGINAL_HOME="${HOME:-}"
  export HOME="${TEST_TMPDIR}/home"
  mkdir -p "${HOME}"
  SCRIPT_PATH="${BATS_TEST_DIRNAME}/icloud.sh"
  ICLOUD_SOURCE="${HOME}/Library/Mobile Documents/com~apple~CloudDocs"
  TARGET_LINK="${HOME}/iCloud"
}

teardown() {
  rm -rf "${TEST_TMPDIR}"
  if [[ -n "${ORIGINAL_HOME}" ]]; then
    export HOME="${ORIGINAL_HOME}"
  else
    unset HOME
  fi
}

@test "setup skips when source missing" {
  run env HOME="${HOME}" "${SCRIPT_PATH}" setup
  [ "$status" -eq 0 ]
  [[ "$output" == *"iCloud Drive not found"* ]]
  [ ! -e "${TARGET_LINK}" ]
}

@test "setup creates symlink when source present" {
  mkdir -p "${ICLOUD_SOURCE}"
  run env HOME="${HOME}" "${SCRIPT_PATH}" setup
  [ "$status" -eq 0 ]
  [ -L "${TARGET_LINK}" ]
  [[ "$(readlink "${TARGET_LINK}")" == "${ICLOUD_SOURCE}" ]]
}

@test "setup leaves existing symlink pointing correctly" {
  mkdir -p "${ICLOUD_SOURCE}"
  ln -s "${ICLOUD_SOURCE}" "${TARGET_LINK}"
  run env HOME="${HOME}" "${SCRIPT_PATH}" setup
  [ "$status" -eq 0 ]
  [ -L "${TARGET_LINK}" ]
  [[ "$(readlink "${TARGET_LINK}")" == "${ICLOUD_SOURCE}" ]]
}

@test "setup fails when target exists and is not symlink" {
  mkdir -p "${ICLOUD_SOURCE}"
  echo "conflict" > "${TARGET_LINK}"
  run env HOME="${HOME}" "${SCRIPT_PATH}" setup
  [ "$status" -eq 1 ]
  [ ! -L "${TARGET_LINK}" ]
  [[ "$(cat "${TARGET_LINK}")" == "conflict" ]]
}

@test "icloud.sh help shows usage information" {
  run "${SCRIPT_PATH}" help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage:"* ]]
  [[ "$output" == *"Manage iCloud Drive symlink and diagnose sync issues"* ]]
  [[ "$output" == *"setup"* ]]
  [[ "$output" == *"diagnose"* ]]
}

@test "icloud.sh --help shows usage information" {
  run "${SCRIPT_PATH}" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage:"* ]]
}

@test "icloud.sh -h shows usage information" {
  run "${SCRIPT_PATH}" -h
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage:"* ]]
}

@test "icloud.sh with no arguments shows help" {
  run "${SCRIPT_PATH}"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage:"* ]]
}

@test "icloud.sh with unknown command warns and shows help" {
  run "${SCRIPT_PATH}" --invalid-option
  [ "$status" -eq 0 ]
  [[ "$output" == *"Ignoring unknown argument"* ]]
}
