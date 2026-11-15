#!/usr/bin/env python3
"""Offline bootstrap checks with fake installers/services; never touch the VM."""

import argparse
import os
from pathlib import Path
import subprocess
import tempfile
import unittest


SCRIPT = Path(__file__).with_name("bootstrap.sh").resolve()


class BootstrapTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix="motherbox-bootstrap-")
        self.addCleanup(self.tmp.cleanup)
        self.home = Path(self.tmp.name)

    def shell(self, body, *, ok=True):
        env = {**os.environ, "HOME": str(self.home), "BOOTSTRAP": str(SCRIPT)}
        for key in list(env):
            if key.startswith(("ANTHROPIC_", "OPENAI_", "GIT_", "HERDR_CORE_")):
                env.pop(key)
        result = subprocess.run(
            ["bash", "-c", 'source "$BOOTSTRAP"\n' + body],
            env=env, text=True, capture_output=True,
        )
        if ok:
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        else:
            self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
        return result

    def test_help_from_file_and_stdin(self):
        for command, stdin in [
            (["bash", str(SCRIPT), "--help"], None),
            (["bash", "-s", "--", "--help"], SCRIPT.read_text()),
        ]:
            result = subprocess.run(command, input=stdin, text=True, capture_output=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertIn("multi-repository", result.stdout)

    def test_unknown_options_fail(self):
        self.shell("main --surprise", ok=False)

    def test_preflight_rejects_mac_and_root(self):
        self.shell("uname() { echo Darwin; }; preflight", ok=False)
        self.shell("uname() { echo Linux; }; id() { echo 0; }; preflight", ok=False)

    def test_existing_agents_and_runtime_are_not_updated(self):
        result = self.shell("""
claude() { echo 'claude existing'; }
codex() { echo 'codex existing'; }
herdr-core() { echo 'hc existing'; }
sudo() { echo 'unexpected sudo' >&2; exit 99; }
curl() { echo 'unexpected download' >&2; exit 99; }
install_agents
install_herdr
""")
        self.assertIn("hc existing", result.stdout)

    def test_fresh_runtime_uses_version_pin_and_cleans_installer(self):
        self.shell("""
command() {
    if [[ $* == '-v herdr-core' && ! -f $HOME/installed ]]; then return 1; fi
    builtin command "$@"
}
curl() {
    while (($#)); do
        if [[ $1 == -o ]]; then
            printf 'test "$HC_VERSION" = 0.1.20\\ntouch "$HOME/installed"\\n' > "$2"
            printf '%s' "$2" > "$HOME/installer-path"
            return
        fi
        shift
    done
    return 1
}
herdr-core() { echo 'hc 0.1.20'; }
install_herdr
test -f "$HOME/installed"
test ! -f "$(cat "$HOME/installer-path")"
""")

    def test_failed_download_stops_installation(self):
        self.shell("""
command() {
    if [[ $* == '-v herdr-core' ]]; then return 1; fi
    builtin command "$@"
}
curl() { return 22; }
install_herdr
""", ok=False)

    def test_service_creation_and_rerun_preserve_unit(self):
        self.shell("""
# Redirect the unit path inside the sourced script, never inspect/write /etc.
source <(sed "s|/etc/systemd/system/herdr-core.service|$HOME/unit|g" "$BOOTSTRAP")
command() {
    if [[ $* == '-v herdr-core' ]]; then echo /home/exedev/.local/bin/herdr-core
    else builtin command "$@"; fi
}
systemctl() {
    if [[ ${1:-} == cat ]]; then test -f "$HOME/unit"; else return 0; fi
}
sudo() {
    printf '%s\\n' "$*" >> "$HOME/sudo-calls"
    shift # -n
    if [[ $1 == tee ]]; then cat > "$HOME/unit"; fi
}
herdr-core() { [[ $* == 'server status' ]]; }
install_herdr_service
cp "$HOME/unit" "$HOME/unit-before"
install_herdr_service
cmp "$HOME/unit" "$HOME/unit-before"
test "$(grep -c 'tee ' "$HOME/sudo-calls")" = 1
! grep -Eq 'restart|server stop' "$HOME/sudo-calls"
grep -q 'Type=oneshot' "$HOME/unit"
grep -q "Requires=user@$(id -u).service" "$HOME/unit"
grep -q "Environment=XDG_RUNTIME_DIR=/run/user/$(id -u)" "$HOME/unit"
test "$(grep -c 'loginctl enable-linger' "$HOME/sudo-calls")" = 1
grep -q 'WantedBy=multi-user.target' "$HOME/unit"
""")

    def test_missing_logins_and_integrations_are_warnings(self):
        result = self.shell("""
claude() { return 1; }
codex() { return 1; }
curl() { return 22; }
check_auth
check_integrations
""")
        self.assertIn("claude auth login", result.stderr)
        self.assertIn("codex login --device-auth", result.stderr)
        self.assertIn("Could not discover integrations", result.stderr)

    def test_auth_output_does_not_expose_provider_details(self):
        result = self.shell("""
claude() {
    echo '{"loggedIn":true,"authMethod":"claude.ai","private":"DO_NOT_PRINT"}'
}
codex() { echo 'Logged in using ChatGPT'; }
check_auth
""")
        self.assertIn("logged in with ChatGPT", result.stdout)
        self.assertNotIn("DO_NOT_PRINT", result.stdout + result.stderr)

    def test_provider_settings_are_warned_about_not_rewritten(self):
        self.shell("""
mkdir -p "$HOME/.claude" "$HOME/.codex"
printf '{"apiKeyHelper":"DO_NOT_PRINT","hooks":{}}' > "$HOME/.claude/settings.json"
printf 'model_provider = "exe-llm"\\n' > "$HOME/.codex/config.toml"
cp "$HOME/.claude/settings.json" "$HOME/claude-before"
cp "$HOME/.codex/config.toml" "$HOME/codex-before"
claude() { return 1; }
codex() { return 1; }
check_auth
cmp "$HOME/.claude/settings.json" "$HOME/claude-before"
cmp "$HOME/.codex/config.toml" "$HOME/codex-before"
""")

    def test_full_bootstrap_can_rerun_without_touching_projects(self):
        self.shell("""
# No package downloads, real provider CLIs, or live systemd access.
preflight() { :; }
install_base_tools() { :; }
install_herdr_service() { :; }
claude() {
    if [[ $1 == --version ]]; then echo 'claude existing'
    else echo '{"loggedIn":true,"authMethod":"claude.ai"}'; fi
}
codex() {
    if [[ $1 == --version ]]; then echo 'codex existing'
    else echo 'Logged in using ChatGPT'; fi
}
herdr-core() { echo 'hc existing'; }
curl() { echo '{"integrations":[{"name":"example","type":"github"}]}'; }
sudo() { echo 'unexpected sudo' >&2; exit 99; }
mkdir -p "$HOME/projects/existing"
printf 'precious work\\n' > "$HOME/projects/existing/work"
main
main
test "$(cat "$HOME/projects/existing/work")" = 'precious work'
test ! -e "$HOME/.gitconfig"
test ! -e "$HOME/.config/gh"
""")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.parse_args()
    unittest.main(argv=[__file__], verbosity=2)
