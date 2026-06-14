# Testing

Tests use [BATS](https://github.com/bats-core/bats-core) and are co-located with
the code they test.

## Philosophy

- Write lightweight smoke tests only
- Test setup workflows that are valuable, practical to run on a laptop, and practical to run in CI
- A test failure should indicate something meaningful is broken
- Prefer real commands and isolated `HOME` directories over complex mocks
- Do not chase comprehensive unit coverage for setup scripts
- Never test implementation details (exact log formats, internal variable names)

## Running Tests

```bash
./run/test.sh                    # Run all tests (lint + unit)
./run/test.sh unit               # BATS tests only
./run/test.sh lint               # ShellCheck only
./run/test.sh --app appname      # Tests for specific app
```

## Test File Template

For `apps/{app}/test_{app}.bats`:

```bash
#!/usr/bin/env bats

load '../../lib/bash/common_test_helper.bash'

setup() {
  TEST_TMPDIR="$(mktemp -d)"
  ORIGINAL_HOME="${HOME:-}"
  export HOME="${TEST_TMPDIR}/home"
  mkdir -p "${HOME}"

  SCRIPT_PATH="${BATS_TEST_DIRNAME}/appname.sh"
}

teardown() {
  rm -rf "${TEST_TMPDIR}"
  if [[ -n "${ORIGINAL_HOME}" ]]; then
    export HOME="${ORIGINAL_HOME}"
  else
    unset HOME
  fi
}

@test "appname.sh shows help with no arguments" {
  run bash "${SCRIPT_PATH}"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage:"* ]]
}

@test "appname.sh errors on unknown argument" {
  run bash "${SCRIPT_PATH}" --invalid
  [ "$status" -eq 1 ]
  [[ "$output" == *"Unknown argument"* ]]
}

@test "appname.sh setup performs expected action" {
  # Create any required preconditions
  run env HOME="${HOME}" bash "${SCRIPT_PATH}" setup
  [ "$status" -eq 0 ]
  # Assert expected outcomes
}

```

## Common Patterns

### Isolate HOME

Override HOME to prevent tests from modifying real user files:

```bash
setup() {
  TEST_TMPDIR="$(mktemp -d)"
  ORIGINAL_HOME="${HOME:-}"
  export HOME="${TEST_TMPDIR}/home"
  mkdir -p "${HOME}"
}

teardown() {
  rm -rf "${TEST_TMPDIR}"
  export HOME="${ORIGINAL_HOME}"
}
```

### Test Helper Functions

The shared helper (`lib/bash/common_test_helper.bash`) provides:

- Sources `common.sh` functions
- Overrides `fail()` to return instead of exit (prevents BATS process termination)
- `create_minimal_path <tmpdir> <exclude_cmd>` - Creates PATH with essential
  commands, excluding one
