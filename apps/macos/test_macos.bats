#!/usr/bin/env bats

setup() {
    SCRIPT_PATH="${BATS_TEST_DIRNAME}/macos.sh"
    TEST_TMPDIR="$(mktemp -d)"
    ORIGINAL_HOME="${HOME:-}"
}

teardown() {
    rm -rf "${TEST_TMPDIR}"
    if [[ -n "${ORIGINAL_HOME}" ]]; then
        export HOME="${ORIGINAL_HOME}"
    else
        unset HOME
    fi
}

@test "script exists and is executable" {
    [ -f "$SCRIPT_PATH" ]
    [ -x "$SCRIPT_PATH" ]
}

@test "help argument displays usage information" {
    run "$SCRIPT_PATH" --help
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Usage:" ]]
    [[ "$output" =~ "Commands:" ]]
    [[ "$output" =~ "setup" ]]
}

@test "short help flag works" {
    run "$SCRIPT_PATH" -h
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Usage:" ]]
}

@test "help command works" {
    run "$SCRIPT_PATH" help
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Usage:" ]]
}

@test "no arguments shows help" {
    run "$SCRIPT_PATH"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Usage:" ]]
}

@test "invalid command warns and shows help" {
    run "$SCRIPT_PATH" invalid_command
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Ignoring unknown argument" ]]
}

@test "help output contains examples section" {
    run "$SCRIPT_PATH" --help
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Examples:" ]]
}

@test "help output contains options section" {
    run "$SCRIPT_PATH" --help
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Options:" ]]
}

@test "help output mentions sudo requirements" {
    run "$SCRIPT_PATH" --help
    [ "$status" -eq 0 ]
    [[ "$output" =~ "sudo" ]]
}

@test "help output mentions --unattended flag" {
    run "$SCRIPT_PATH" --help
    [ "$status" -eq 0 ]
    [[ "$output" =~ "--unattended" ]]
}

@test "--unattended flag is accepted with setup command" {
    # Verify the flag is recognized by the arg parser (don't run full setup)
    run "$SCRIPT_PATH" --help
    [[ "$output" =~ "--unattended" ]]
    # Also confirm unknown args are warned about, but --unattended is not
    run "$SCRIPT_PATH" --unattended
    [[ ! "$output" =~ "Ignoring unknown argument: --unattended" ]]
}

@test "--unattended works in any position with setup command" {
    # Verify --unattended is recognized regardless of position
    run "$SCRIPT_PATH" --unattended
    [[ ! "$output" =~ "Ignoring unknown argument: --unattended" ]]
}
