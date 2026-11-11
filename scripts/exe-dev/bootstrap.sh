#!/usr/bin/env bash
# Standalone: copy this file to a VM, paste it, or feed it to ssh ... 'bash -s'.
set -euo pipefail

usage() {
    cat <<'EOF'
Usage: bootstrap.sh [-h|--help]

Bootstrap a multi-repository Herdr workstation on a current exe.dev exeuntu VM.
Run as the normal VM user, not root. Requires passwordless sudo when installing.

Installs missing tools, enables Herdr startup, creates ~/projects, and reports
provider login and attached integration status. Safe to rerun: existing tools,
credentials, provider settings, Git identities, and project contents are kept.
No projects are cloned, agents launched, or GitHub writes performed.

Optional environment:
  HERDR_CORE_VERSION  Release for a NEW installation (default: 0.1.20).
                      Existing installations are never updated by this script.

From a laptop:
  ssh my-vm.exe.xyz 'bash -s' < scripts/exe-dev/bootstrap.sh

Afterwards, log into Claude/Codex interactively and attach repo integrations
through exe.dev. See docs/exe-dev.md for the complete setup checklist.
EOF
}

log() { printf '\n==> %s\n' "$*"; }
warn() { printf 'WARNING: %s\n' "$*" >&2; }
die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

preflight() {
    [[ $(uname -s) == Linux ]] || die "Run this on the exe.dev Linux VM, not your Mac."
    [[ $(id -u) != 0 ]] || die "Run as the VM user; do not run the script with sudo."
    [[ -d /run/systemd/system ]] || die "This bootstrap requires a systemd-based exeuntu VM."
    # These values are embedded in a systemd unit; keep their syntax unambiguous.
    [[ $HOME =~ ^/[a-zA-Z0-9_./-]+$ ]] || die "Unsupported HOME path: $HOME"
    command -v sudo >/dev/null || die "sudo is required."
    export PATH="$HOME/.local/bin:$PATH"
}

install_base_tools() {
    local tool
    local missing=()
    for tool in curl git gh jq tar; do
        command -v "$tool" >/dev/null || missing+=("$tool")
    done
    if ((${#missing[@]})); then
        log "Installing missing packages: ${missing[*]}"
        sudo -n apt-get update
        sudo -n env DEBIAN_FRONTEND=noninteractive apt-get install -y \
            ca-certificates "${missing[@]}"
    fi
}

install_agents() {
    local agent
    for agent in claude codex; do
        if ! command -v "$agent" >/dev/null; then
            command -v exeuntu >/dev/null ||
                die "$agent is missing and exeuntu is unavailable. Use a current exeuntu image."
            log "Installing $agent with the image's supported installer"
            sudo -n exeuntu update "$agent"
        fi
        "$agent" --version
    done
    # Deliberately do not run `exeuntu configure`: it selects the LLM gateway,
    # whereas this workstation uses direct Claude and ChatGPT subscriptions.
}

install_herdr() {
    local installer version=${HERDR_CORE_VERSION:-0.1.20}
    if ! command -v herdr-core >/dev/null; then
        log "Installing herdr-core $version"
        installer=$(mktemp)
        if ! curl -fsSL --connect-timeout 10 --max-time 120 \
            https://releases.herdr.dev/core/install.sh -o "$installer"; then
            rm -f "$installer"
            die "Could not download the Herdr installer."
        fi
        # The official installer verifies its release archive's SHA-256 checksum.
        if ! HC_VERSION="$version" HC_INSTALL_DIR="$HOME/.local/bin" sh "$installer"; then
            rm -f "$installer"
            die "Herdr installation failed."
        fi
        rm -f "$installer"
    fi
    herdr-core --version
}

install_herdr_service() {
    local core unit user uid
    core=$(command -v herdr-core)
    [[ $core =~ ^/[a-zA-Z0-9_./-]+$ ]] || die "Unsupported herdr-core executable path: $core"
    user=$(id -un)
    uid=$(id -u)
    unit=/etc/systemd/system/herdr-core.service
    if ! systemctl cat herdr-core.service >/dev/null 2>&1; then
        log "Installing Herdr boot startup service"
        # Do not overwrite a dangling symlink or a unit we cannot inspect.
        [[ ! -e $unit && ! -L $unit ]] || die "Inspect the existing $unit before proceeding."
        sudo -n loginctl enable-linger "$user"
        sudo -n tee "$unit" >/dev/null <<EOF
[Unit]
Description=Herdr Core startup for $user
Requires=user@$uid.service
After=network.target user@$uid.service

[Service]
Type=oneshot
User=$user
Environment=HOME=$HOME
Environment=XDG_RUNTIME_DIR=/run/user/$uid
Environment=PATH=$HOME/.local/bin:/usr/local/bin:/usr/bin:/bin
ExecStart=$core server start
ExecStop=$core server stop
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF
        sudo -n systemctl daemon-reload
    else
        log "Keeping the existing herdr-core.service unchanged"
    fi
    # `start` is a no-op for an active unit; no restart/stop of running sessions.
    sudo -n systemctl enable --now herdr-core.service
    systemctl is-enabled herdr-core.service
    systemctl is-active herdr-core.service
    herdr-core server status
    # This oneshot starts Herdr at boot; it is NOT a crash watchdog.
}

check_auth() {
    local status
    log "Provider authentication (no credentials are printed)"
    if status=$(claude auth status 2>/dev/null) &&
        jq -e '.loggedIn == true and .authMethod == "claude.ai"' \
            >/dev/null 2>&1 <<<"$status"; then
        printf 'Claude: logged in with a Claude account.\n'
    else
        warn "Claude subscription login not confirmed. Run: claude auth login"
    fi
    if status=$(codex login status 2>&1) && [[ $status == *"ChatGPT"* ]]; then
        printf 'Codex: logged in with ChatGPT.\n'
    else
        warn "Codex ChatGPT login not confirmed. Run: codex login --device-auth"
    fi
    # Warn, never silently remove existing provider configuration or hooks.
    if [[ -f $HOME/.claude/settings.json ]] &&
        jq -e '.apiKeyHelper or .env.ANTHROPIC_BASE_URL or .env.ANTHROPIC_API_KEY or .env.ANTHROPIC_AUTH_TOKEN' \
            >/dev/null 2>&1 "$HOME/.claude/settings.json"; then
        warn "Claude has provider overrides in settings.json; review before using subscription billing."
    fi
    if [[ -f $HOME/.codex/config.toml ]] &&
        grep -Eq '^[[:space:]]*model_provider[[:space:]]*=' "$HOME/.codex/config.toml"; then
        warn "Codex has model_provider settings; review before using subscription billing."
    fi
    if [[ -n ${ANTHROPIC_API_KEY:-}${ANTHROPIC_AUTH_TOKEN:-}${ANTHROPIC_BASE_URL:-}${OPENAI_API_KEY:-}${OPENAI_BASE_URL:-} ]]; then
        warn "Provider environment overrides are present; review before using subscription billing."
    fi
}

check_integrations() {
    local metadata
    log "Attached exe.dev integrations"
    if metadata=$(curl -fsS --connect-timeout 5 --max-time 15 \
        https://reflection.int.exe.xyz/integrations) &&
        jq -e '.integrations | type == "array"' >/dev/null 2>&1 <<<"$metadata"; then
        jq -r '.integrations[] | "  \(.type): \(.name)"' <<<"$metadata"
        if ! jq -e 'any(.integrations[]; .type == "github")' >/dev/null <<<"$metadata"; then
            warn "No GitHub repo integrations attached. Add them in the exe.dev Integrations UI."
        fi
    else
        warn "Could not discover integrations. Check that reflection is attached in exe.dev."
    fi
    printf '\nGitHub CLI usage: GH_HOST=github.int.exe.xyz gh repo view OWNER/REPO\n'
}

main() {
    case ${1:-} in
        -h|--help) usage; return ;;
        "") ;;
        *) usage >&2; die "Unknown argument: $1" ;;
    esac
    (($# == 0)) || die "Unexpected arguments."
    preflight
    install_base_tools
    log "Agent tools (existing versions are preserved)"
    install_agents
    install_herdr
    install_herdr_service
    mkdir -p "$HOME/projects"
    check_auth
    check_integrations
    log "Bootstrap complete"
    printf 'Projects directory: %s/projects\n' "$HOME"
    printf 'Next: complete any login warnings; add this VM in Herdr desktop;\n'
    printf 'clone individual projects and explicitly choose their Git identities.\n'
    printf 'No Git identity, GitHub host default, or provider config was changed.\n'
}

if [[ ${BASH_SOURCE[0]:-$0} == "$0" ]]; then
    main "$@"
fi
