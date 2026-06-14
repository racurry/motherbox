# 1Password

Password manager with built-in SSH agent. [Official docs](https://developer.1password.com/docs/ssh/).

## Installation

1Password must be installed manually before this repo can be cloned. See the [main README](/README.md) for bootstrap instructions.

## Setup

```bash
./apps/1password/1password.sh setup --profile personal  # or --profile firsthand
```

Setup does three things, all via symlink:

1. Symlinks `~/.1password/agent.sock` to the real 1Password agent socket.
2. Symlinks `~/.ssh/config` to the active `ssh_config`.
3. Symlinks `~/.config/1password/ssh/agent.toml` to the profile's `agent.toml`.

`agent.toml` lives per-profile under `apps/1password/<profile>/`. `ssh_config`
is shared (`apps/1password/ssh_config`).

### Machine-specific SSH config

When a machine is set (via `--machine` or persisted config), setup prefers
`<profile>/<machine>/ssh_config` over `<profile>/ssh_config` if it exists. This
lets a specific machine override how SSH is configured without affecting the
shared profile.

Example: `personal/mini/ssh_config` takes the 1Password agent out of the SSH
path for `github.com` and uses a local on-disk key (`~/.ssh/id_ed25519_mini`)
instead. The `Host github.com` block is placed before `Host *` so that
`IdentityAgent none` wins (ssh uses the first value obtained per host). The
private key must already exist on the machine; it is not exported from 1Password.

## Manual Setup

Complete these steps during initial installation (before cloning this repo):

1. **Download and install** - [1password.com/downloads/mac](https://1password.com/downloads/mac)

2. **Sign in** - Add your 1Password account(s)

3. **Enable SSH agent** - Settings > Developer > SSH Agent

4. **Configure SSH client** - Add to `~/.ssh/config`:

   ```text
   Host *
       IdentityAgent "~/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"
   ```

After running the setup script:

1. **Restart 1Password** - Lock and unlock to recognize the new agent.toml

## Syncing Preferences

Repo sync. SSH agent config (`agent.toml`) and SSH client config (`ssh_config`) symlinked into place from the active profile. App preferences sync via 1Password account.

## References

- [SSH Agent Config File](https://developer.1password.com/docs/ssh/agent/config/)
- [Get Started with SSH](https://developer.1password.com/docs/ssh/get-started/)
