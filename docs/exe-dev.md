# exe.dev agent workstation

A multi-repository Linux VM for Herdr desktop, Claude Code, and Codex.
This is separate from `mother setup`, Mac provisioning, and chezmoi.
Do **not** apply the Mac dotfiles to the VM.

## Bootstrap

Create a current default `exeuntu` VM in exe.dev. From a local motherbox checkout:

```bash
ssh my-vm.exe.xyz 'bash -s' < scripts/exe-dev/bootstrap.sh
```

Or copy the **single file** onto the VM and run `bash bootstrap.sh`. It has no
dependency on motherbox libraries, the current working directory, or a checkout
of this repository. Use Bash, not `sh`. Inspect scripts before running them.

The script:

- Installs missing base packages using apt and missing Claude/Codex using
  `exeuntu update`; existing versions are left alone.
- Installs missing `herdr-core` using the official checksum-verifying installer.
  The initial release defaults to `0.1.20`; override `HERDR_CORE_VERSION` on the
  **remote** command to choose another release:
  `ssh my-vm.exe.xyz 'HERDR_CORE_VERSION=0.1.20 bash -s' < scripts/exe-dev/bootstrap.sh`.
  This does not downgrade or upgrade an existing installation.
- Creates/enables a system-wide `herdr-core.service` running as the VM user.
  For a new service it enables user lingering and orders startup after the user
  manager, so Herdr uses the same `/run/user/UID` socket location at boot and login.
  An existing service is preserved. It starts Herdr after a reboot without
  restarting existing sessions on reruns. It is a boot-start oneshot, not a
  crash watchdog. Reboots still terminate running programs.
- Creates `~/projects` and reports subscription login and attached integrations.

Run as the ordinary VM user, with passwordless sudo available. Reruns preserve
credentials, provider settings, hooks, Git identities, and project contents.
Missing login/integration checks are warnings so initial provisioning can finish;
installation/service failures are errors. The script does not launch an agent,
consume model usage, copy secrets, clone projects, push code, or open PRs.
This reproduces provisioning, **not** a backup of conversations or unpushed work.

## Supported exe.dev provisioning options

exe.dev's [customization guide](https://exe.dev/docs/customization.md) documents
three approaches: configure an existing VM over SSH (including scripts),
create VMs from a custom Docker/OCI image, or run a setup script once at first
boot. SSH customization is described as the simplest and most common approach.
The guide does not prescribe a declarative environment manifest or a particular
configuration-management tool.

For this workstation, the versioned bootstrap is our provisioning source of
truth, not a declarative reconciler or a complete lockfile. It preserves installed
versions rather than enforcing exact tool versions. If we later need identical
base tool versions on every fresh VM, a versioned custom image is the documented
next option; provider logins and integration attachments still live outside it.

We can also reuse this **same script at VM creation**, rather than copying it
afterwards:

```bash
ssh exe.dev new --name=my-vm --setup-script /dev/stdin \
  < scripts/exe-dev/bootstrap.sh
```

On the current exeuntu image, the
[first-boot setup service](https://github.com/boldsoftware/exeuntu/blob/main/exe-setup.service)
runs as `exedev` with its home set, matching this script's normal-user requirement.
Setup scripts run once, not at every boot, and have a size limit; if the payload
is too large, use the SSH bootstrap path above. For a failed setup, inspect
`journalctl -u exe-setup.service` on the VM and rerun this script over SSH.
Nothing here creates a VM or changes defaults automatically.

Optionally, exe.dev also documents account-wide defaults:

```bash
# Opt in: run this bootstrap on subsequently created VMs.
ssh exe.dev defaults write dev.exe new.setup-script \
  < scripts/exe-dev/bootstrap.sh

# Remove that default later.
ssh exe.dev defaults delete dev.exe new.setup-script
```

The same setup-script size limit applies. This is optional account configuration,
not something the bootstrap itself changes.

## Supported Herdr setup

There **is** an [official exe.dev Herdr deployment recipe](https://exe.dev/deploy/herdr.md).
It installs `herdr-core` using the same upstream installer as this script and
connects the desktop app over SSH. This is a supported deployment path, not a
separate credential-injecting Herdr integration like the GitHub/LLM integrations.
Herdr's own agent-status integrations are a different feature again.

The recipe additionally installs the separate Herdr TUI and configures exe.dev's
LLM gateway. We intentionally omit both: this workstation uses the desktop app
and direct Claude/ChatGPT subscriptions, which the recipe's FAQ also covers.
The boot-start systemd unit in our script is our provisioning choice, not a
service file copied from the recipe.

## Account and desktop checklist

1. On the VM, authenticate directly with the existing subscriptions:
   ```bash
   claude auth login
   codex login --device-auth
   ```
   Complete the private browser steps yourself. Device login may require enabling
   device-code authentication in ChatGPT security settings. Do not paste tokens
   into chat or commit credential files.
2. Do not run `exeuntu configure claude` or `exeuntu configure codex`: those select
   the exe.dev model gateway rather than direct subscriptions. If an earlier
   setup added gateway overrides, inspect/remove only those settings manually;
   preserve unrelated settings and Herdr hooks. The bootstrap warns but does not
   rewrite provider files. Review project-level settings and your launch
   environment as well; a successful login alone does not guarantee billing
   routing.
3. In exe.dev, add a GitHub integration for **each** repository agents need and
   attach it to this VM. Choose **act as app**, with read-only off when agents
   should push and open PRs. No personal GitHub login/PAT is needed on the VM.
   Account-level attachments are outside the bootstrap's scope.
4. From the laptop, connect with `ssh my-vm.exe.xyz` once to accept the host key.
   In Herdr desktop, **Add machine → `my-vm.exe.xyz`**.
5. Clone projects, open their folders as Herdr spaces, and launch Claude/Codex.
   The VM needs `herdr-core`, not the separate Herdr TUI or a desktop environment.

Re-run the bootstrap to check login/integration status after these steps.
`~/.local/bin` is included in the service's PATH; the official installer also
prints a PATH reminder if the login shell needs configuring. If a desktop SSH
connection cannot find the runtime, inspect that shell's PATH rather than
overwriting shell startup files.

## Add a project

Run on the VM, replacing `OWNER/REPO` and `REPO`:

```bash
git clone https://github.int.exe.xyz/OWNER/REPO.git ~/projects/REPO
GH_HOST=github.int.exe.xyz gh repo view OWNER/REPO
```

The integration authenticates Git pushes and GitHub API actions as the exe.dev
App. Commit metadata is independent: choose each repository's name/email
explicitly. The bot's GitHub account ID was verified as `267204973`:

```bash
git -C ~/projects/REPO config --local user.name 'exe-dev-github-integration[bot]'
git -C ~/projects/REPO config --local user.email \
  '267204973+exe-dev-github-integration[bot]@users.noreply.github.com'
git -C ~/projects/REPO var GIT_AUTHOR_IDENT
```

These commands change only that repository, not global defaults. Alternatively,
launch agents with `GIT_AUTHOR_NAME`, `GIT_AUTHOR_EMAIL`, `GIT_COMMITTER_NAME`,
and `GIT_COMMITTER_EMAIL` for per-process identities. They override configuration;
setting them in a hook subprocess alone does not export them into its parent.
Neither mechanism changes GitHub permissions or PR authorship.

Prefix GitHub CLI calls with `GH_HOST=github.int.exe.xyz`, including PR creation:

```bash
GH_HOST=github.int.exe.xyz gh pr create --repo OWNER/REPO
```

The bootstrap deliberately does not globally redirect GitHub hosts or rewrite
Git remotes. Do not add personal credentials as a fallback for agents.

Use branches in the same repository. Configure required PR approval on the
default branch in GitHub yourself, then inspect the first PR to confirm the App
is its author and you can review as your personal account. Required approval is
the intended gate here, not a promise that agents lack merge permissions.
No branch protections or test PRs are created by the script.

## Maintenance and validation

Explicit upgrades, independent of bootstrap reruns:

```bash
herdr-core update
sudo exeuntu update claude
sudo exeuntu update codex
```

When adding new tools or changing Herdr's version pin, review the official
documentation below. Keep this script deliberately small and VM-scoped.

Local checks (no installation or live-service changes):

```bash
bash -n scripts/exe-dev/bootstrap.sh
bash scripts/exe-dev/bootstrap.sh --help
python3 scripts/exe-dev/test-bootstrap.py
```

References:

- https://exe.dev/docs/customization.md — SSH, first-boot setup scripts/defaults, custom images
- https://exe.dev/docs/upgrade-codex.md — image tools and supported installers
- https://exe.dev/deploy/herdr.md — remote runtime and direct-subscription caveats
- https://exe.dev/docs/integrations-github.md — App identity and Git/CLI routing
- https://exe.dev/docs/integrations-reflection.md — attached integration discovery
- https://releases.herdr.dev/core/install.sh — official Herdr installer
