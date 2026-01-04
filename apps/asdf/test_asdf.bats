#!/usr/bin/env bats

load '../../lib/bash/common_test_helper.bash'

setup() {
  TEST_TMPDIR="$(mktemp -d)"
  TEST_HOME="${TEST_TMPDIR}/home"
  TEST_REPO_ROOT="${TEST_TMPDIR}/repo"
  TEST_DOTFILES="${TEST_REPO_ROOT}/dotfiles"

  mkdir -p "${TEST_HOME}"
  mkdir -p "${TEST_DOTFILES}"

  ORIGINAL_HOME="${HOME:-}"
  ORIGINAL_REPO_ROOT="${REPO_ROOT:-}"
  export HOME="${TEST_HOME}"
  export REPO_ROOT="${TEST_REPO_ROOT}"

  SCRIPT_PATH="${BATS_TEST_DIRNAME}/asdf.sh"
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

@test "asdf setup fails when asdf not installed" {
  # Create a minimal PATH excluding asdf
  create_minimal_path "${TEST_TMPDIR}" "asdf"

  run env PATH="${TEST_TMPDIR}/bin" HOME="${HOME}" REPO_ROOT="${REPO_ROOT}" bash "${SCRIPT_PATH}" setup
  [ "$status" -eq 1 ]
  [[ "$output" == *"Required command 'asdf' not found in PATH"* ]]
}

@test "asdf setup unsets version environment variables" {
  # Create test .tool-versions file
  cat > "${TEST_DOTFILES}/.tool-versions" << 'EOF'
nodejs 18.17.0
EOF

  # Set some version environment variables
  export ASDF_RUBY_VERSION="3.0.0"
  export ASDF_NODEJS_VERSION="16.0.0"
  export ASDF_PYTHON_VERSION="3.9.0"

  # Create mock asdf command that checks environment
  mkdir -p "${TEST_TMPDIR}/bin"
  cat > "${TEST_TMPDIR}/bin/asdf" << 'EOF'
#!/bin/bash
if [[ "$1" == "install" ]]; then
  echo "ASDF_RUBY_VERSION: ${ASDF_RUBY_VERSION:-unset}"
  echo "ASDF_NODEJS_VERSION: ${ASDF_NODEJS_VERSION:-unset}"
  echo "ASDF_PYTHON_VERSION: ${ASDF_PYTHON_VERSION:-unset}"
  exit 0
fi
exit 0
EOF
  chmod +x "${TEST_TMPDIR}/bin/asdf"

  run env PATH="${TEST_TMPDIR}/bin:${PATH}" HOME="${HOME}" REPO_ROOT="${REPO_ROOT}" ASDF_RUBY_VERSION="${ASDF_RUBY_VERSION}" ASDF_NODEJS_VERSION="${ASDF_NODEJS_VERSION}" ASDF_PYTHON_VERSION="${ASDF_PYTHON_VERSION}" bash "${SCRIPT_PATH}" setup
  [ "$status" -eq 0 ]
  [[ "$output" == *"ASDF_RUBY_VERSION: unset"* ]]
  [[ "$output" == *"ASDF_NODEJS_VERSION: unset"* ]]
  [[ "$output" == *"ASDF_PYTHON_VERSION: unset"* ]]
}

@test "asdf shows help with no arguments" {
  run bash "${SCRIPT_PATH}"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage:"* ]]
  [[ "$output" == *"setup"* ]]
}

@test "asdf update command runs brew update and plugin update" {
  # Create mock brew command
  mkdir -p "${TEST_TMPDIR}/bin"
  cat > "${TEST_TMPDIR}/bin/brew" << 'EOF'
#!/bin/bash
if [[ "$1" == "update" ]]; then
  echo "Brew updated"
  exit 0
fi
exit 0
EOF
  chmod +x "${TEST_TMPDIR}/bin/brew"

  # Create mock asdf command that logs the update command
  cat > "${TEST_TMPDIR}/bin/asdf" << 'EOF'
#!/bin/bash
if [[ "$1" == "plugin" && "$2" == "update" && "$3" == "--all" ]]; then
  echo "Updating all plugins"
  exit 0
fi
exit 0
EOF
  chmod +x "${TEST_TMPDIR}/bin/asdf"

  run env PATH="${TEST_TMPDIR}/bin:${PATH}" HOME="${HOME}" REPO_ROOT="${REPO_ROOT}" bash "${SCRIPT_PATH}" update
  [ "$status" -eq 0 ]
  [[ "$output" == *"Brew updated"* ]]
  [[ "$output" == *"Updating all plugins"* ]]
}

@test "asdf help shows update command" {
  run bash "${SCRIPT_PATH}" help
  [ "$status" -eq 0 ]
  [[ "$output" == *"update"* ]]
  [[ "$output" == *"Update brew and all asdf plugins"* ]]
}

