# 1Password

Password manager with built-in SSH agent. [Official docs](https://developer.1password.com/docs/ssh/).

## Installation

1Password must be installed manually before this repo can be cloned. See the [main README](/README.md) for bootstrap instructions.

## Setup

```bash
./apps/1password/1password.sh setup --profile personal  # or --profile galileo
```

This symlinks the appropriate SSH agent config (`agent.personal.toml` or `agent.galileo.toml`) to `~/.config/1password/ssh/agent.toml`.

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

Repo sync. SSH agent config (`agent.toml`) symlinked to `~/.config/1password/ssh/`. App preferences sync via 1Password account.

## References

- [SSH Agent Config File](https://developer.1password.com/docs/ssh/agent/config/)
- [Get Started with SSH](https://developer.1password.com/docs/ssh/get-started/)
