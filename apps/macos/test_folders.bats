#!/usr/bin/env bats

setup() {
  TEST_TMPDIR="$(mktemp -d)"
  ORIGINAL_HOME="${HOME:-}"
  export HOME="${TEST_TMPDIR}/home"
  mkdir -p "${HOME}"
  SCRIPT_PATH="${BATS_TEST_DIRNAME}/folders.sh"
}

teardown() {
  rm -rf "${TEST_TMPDIR}"
  if [[ -n "${ORIGINAL_HOME}" ]]; then
    export HOME="${ORIGINAL_HOME}"
  else
    unset HOME
  fi
}

@test "create_documents_tree creates expected folders" {
  run env HOME="${HOME}" "${SCRIPT_PATH}" setup --profile personal --unattended
  [ "$status" -eq 0 ]
  for folder in "@auto" 000_Inbox 100_Areas 200_People 300_Time 400_Topics 500_Projects 600_Output 800_Libraries 900_Sharing 999_Meta; do
    [ -d "${HOME}/Documents/${folder}" ]
  done
}

@test "create_documents_tree creates code folders" {
  run env HOME="${HOME}" "${SCRIPT_PATH}" setup --profile personal --unattended
  [ "$status" -eq 0 ]
  [ -d "${HOME}/code/me" ]
  [ -d "${HOME}/code/me/_archive" ]
  [ -d "${HOME}/code/me/_scratch" ]
  [ -d "${HOME}/code/vendor" ]
}

@test "create_documents_tree is idempotent" {
  env HOME="${HOME}" "${SCRIPT_PATH}" setup --profile personal --unattended
  run env HOME="${HOME}" "${SCRIPT_PATH}" setup --profile personal --unattended
  [ "$status" -eq 0 ]
}

@test "folders.sh --help shows usage information" {
  run "${SCRIPT_PATH}" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage:"* ]]
  [[ "$output" == *"Create organizational folder structure"* ]]
  [[ "$output" == *"-h, --help"* ]]
}

@test "folders.sh -h shows usage information" {
  run "${SCRIPT_PATH}" -h
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage:"* ]]
  [[ "$output" == *"Create organizational folder structure"* ]]
  [[ "$output" == *"-h, --help"* ]]
}

@test "folders.sh with unknown option warns and shows help" {
  run "${SCRIPT_PATH}" --invalid-option
  [ "$status" -eq 0 ]
  [[ "$output" == *"Ignoring unknown argument"* ]]
}
