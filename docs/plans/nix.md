# Nix Migration Analysis for Motherbox

This document analyzes what it would take to replace the current bash-based macOS
setup system with Nix/nix-darwin/home-manager.

## Executive Summary

**Effort estimate**: Medium-high complexity, 2-4 weeks of focused work

**Recommendation**: The current system works well. Migrate only if you want:

- Atomic rollbacks for system configuration
- Declarative reproducibility across machines
- To contribute to/learn the Nix ecosystem

The main pain points will be: Mac App Store apps, macOS system preferences, and
proprietary GUI applications that don't have Nix packages.

______________________________________________________________________

## Current System Inventory

### What Motherbox Manages Today

| Category                | Count | Examples                                        |
| ----------------------- | ----- | ----------------------------------------------- |
| Homebrew formulae       | ~30   | git, asdf, fzf, shellcheck, ruff, uv            |
| Homebrew casks          | ~30   | 1password-cli, cursor, docker-desktop, obsidian |
| Mac App Store apps      | ~20   | Things, Xcode, Amphetamine, Pixelmator Pro      |
| Runtime versions (asdf) | 3     | Python 3.12, Ruby 3.4, Node 24                  |
| Dotfile symlinks        | ~15   | .zshrc, .gitconfig, .editorconfig               |
| macOS defaults          | ~40   | Dock, Finder, keyboard, screenshots             |
| Folder structure        | ~15   | ~/code/*, ~/Documents/*                         |
| Application configs     | ~10   | Karabiner, 1Password SSH, Claude Code           |

### Package Categories by Nix Compatibility

```
Easy (direct nixpkgs equivalents):
├── CLI tools: git, bat, eza, fzf, ripgrep, fd, jq, shellcheck, shfmt
├── Languages: python, ruby, nodejs (via nix, not asdf)
├── Dev tools: direnv, gh, docker, prettier, eslint
└── Shell: zsh, oh-my-zsh, zsh-autosuggestions, zsh-syntax-highlighting

Medium (available but may need overlays or darwin-specific handling):
├── Homebrew-specific: asdf (replace with nix flakes), pure prompt
├── macOS-only CLIs: mas (no equivalent - see below)
└── Some casks: iterm2, visual-studio-code, obsidian

Hard (no nixpkgs, need homebrew overlay or manual):
├── Proprietary casks: cursor, lm-studio, raycast, keyboard-maestro
├── Niche tools: textbuddy, shottr, mutedeck, elgato-stream-deck
└── Mac App Store: ALL of them (Things, Xcode, Pixelmator, etc.)

Impossible in pure Nix:
├── Mac App Store apps (require Apple ID, no automation API)
├── Some macOS defaults (require SIP disable or manual action)
└── iCloud integration (macOS-specific, no Nix equivalent)
```

______________________________________________________________________

## Architecture Comparison

### Current: Imperative Bash Scripts

```
run/setup.sh
├── lib/bash/common.sh (shared utilities)
├── apps/brew/brew.sh → Brewfile, {mode}.Brewfile
├── apps/zsh/zsh.sh → .zshrc symlink
├── apps/macos/macos.sh → defaults write commands
├── apps/asdf/asdf.sh → .tool-versions
└── apps/*/app.sh → per-app setup
```

**Strengths:**

- Simple, readable bash
- Easy to debug and modify
- Works with any macOS tool
- No learning curve

**Weaknesses:**

- No atomic rollback
- State can drift from definition
- Order-dependent execution
- Manual "what changed?" tracking

### Target: Declarative Nix

```
flake.nix
├── darwin-configuration.nix (nix-darwin)
│   ├── system.defaults.* (macOS preferences)
│   ├── homebrew.* (declarative Homebrew for casks/mas)
│   └── environment.systemPackages
├── home.nix (home-manager)
│   ├── home.packages (user packages)
│   ├── programs.* (per-program config)
│   └── home.file.* (dotfiles)
└── flake.lock (pinned versions)
```

**Strengths:**

- Atomic rollbacks (`darwin-rebuild switch --rollback`)
- Reproducible across machines
- Single source of truth
- Version pinning via flake.lock

**Weaknesses:**

- Steep learning curve (Nix language)
- Slower iteration (rebuild required)
- Mac App Store still needs Homebrew
- Some packages lag behind Homebrew

______________________________________________________________________

## Migration Strategy

### Phase 1: Foundation (Week 1)

1. **Install Nix** (multi-user mode for macOS)

   ```bash
   curl -L https://nixos.org/nix/install | sh -s -- --daemon
   ```

2. **Set up nix-darwin**

   ```bash
   nix-build https://github.com/LnL7/nix-darwin/archive/master.tar.gz -A installer
   ./result/bin/darwin-installer
   ```

3. **Enable Flakes** in `/etc/nix/nix.conf`:

   ```
   experimental-features = nix-command flakes
   ```

4. **Create initial flake.nix**:

   ```nix
   {
     inputs = {
       nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
       darwin.url = "github:LnL7/nix-darwin";
       home-manager.url = "github:nix-community/home-manager";
     };
     outputs = { self, nixpkgs, darwin, home-manager }: {
       darwinConfigurations."your-hostname" = darwin.lib.darwinSystem {
         system = "aarch64-darwin";
         modules = [
           ./darwin-configuration.nix
           home-manager.darwinModules.home-manager
         ];
       };
     };
   }
   ```

### Phase 2: CLI Tools Migration (Week 1-2)

Replace Brewfile formulae with nix packages:

```nix
# darwin-configuration.nix
environment.systemPackages = with pkgs; [
  bat
  diff-so-fancy
  direnv
  eza
  fd
  fzf
  gh
  git
  jq
  ripgrep
  shellcheck
  shfmt
];

# home.nix (home-manager)
home.packages = with pkgs; [
  eslint
  nodePackages.prettier
  python312
  ruby_3_4
  nodejs_22  # or use nix-shell/devenv per-project
  ruff
  uv
];
```

**Key changes:**

- Remove asdf entirely (use nix flakes + direnv for per-project versions)
- Python/Ruby/Node become nix packages or per-project dev shells

### Phase 3: Dotfiles Migration (Week 2)

Convert symlinks to home-manager file declarations:

```nix
# home.nix
home.file = {
  ".zshrc".source = ./dotfiles/zshrc;
  ".gitconfig".source = ./dotfiles/gitconfig;
  ".gitignore_global".source = ./dotfiles/gitignore_global;
  ".editorconfig".source = ./dotfiles/editorconfig;
  ".config/ruff/ruff.toml".source = ./dotfiles/ruff.toml;
  ".config/karabiner/karabiner.json".source = ./dotfiles/karabiner.json;
};

# Or use home-manager's native program modules:
programs.git = {
  enable = true;
  userName = "Your Name";
  userEmail = "you@example.com";
  extraConfig = {
    init.defaultBranch = "main";
    push.autoSetupRemote = true;
  };
};

programs.zsh = {
  enable = true;
  oh-my-zsh.enable = true;
  plugins = [ "git" "docker" ];
  shellAliases = {
    cat = "bat";
    ls = "eza -a";
  };
};
```

### Phase 4: macOS Defaults (Week 2-3)

nix-darwin supports many macOS defaults natively:

```nix
# darwin-configuration.nix
system.defaults = {
  dock = {
    autohide = true;
    orientation = "left";
    tilesize = 36;
    static-only = true;
    mru-spaces = false;
  };
  finder = {
    AppleShowAllFiles = true;
    ShowPathbar = true;
    ShowStatusBar = true;
    FXEnableExtensionChangeWarning = false;
  };
  NSGlobalDomain = {
    AppleShowScrollBars = "Always";
    AppleKeyboardUIMode = 3;
    ApplePressAndHoldEnabled = false;
    InitialKeyRepeat = 15;
    KeyRepeat = 2;
    NSAutomaticCapitalizationEnabled = false;
    NSAutomaticSpellingCorrectionEnabled = false;
  };
  screencapture = {
    location = "~/Screenshots";
    type = "png";
    disable-shadow = true;
  };
};
```

**Not supported by nix-darwin** (keep bash scripts or manual):

- Some advanced dock settings
- Hot corners
- Screensaver configuration
- Sound preferences
- Some accessibility settings

### Phase 5: GUI Applications (Week 3-4)

**Option A: nix-darwin's Homebrew integration** (recommended)

```nix
# darwin-configuration.nix
homebrew = {
  enable = true;
  onActivation = {
    autoUpdate = true;
    cleanup = "zap";  # Remove unlisted packages
  };

  brews = [
    "mas"  # Still needed for Mac App Store
  ];

  casks = [
    "1password-cli"
    "arc"
    "cursor"
    "docker-desktop"
    "iterm2"
    "karabiner-elements"
    "obsidian"
    "raycast"
    "visual-studio-code"
  ];

  masApps = {
    "Things" = 904280696;
    "Amphetamine" = 937984704;
    "Xcode" = 497799835;
  };
};
```

This is the pragmatic approach - let Homebrew handle what it's good at.

**Option B: Pure nix where possible**

Some casks have nixpkgs equivalents:

```nix
environment.systemPackages = with pkgs; [
  iterm2      # available
  obsidian    # available
  vscode      # available as "vscode" or "vscodium"
];
```

But many don't: cursor, raycast, keyboard-maestro, etc.

### Phase 6: Per-Project Dev Environments (Ongoing)

Replace asdf with nix flakes + direnv:

```nix
# project/flake.nix
{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  outputs = { self, nixpkgs }: {
    devShells.aarch64-darwin.default = nixpkgs.legacyPackages.aarch64-darwin.mkShell {
      packages = with nixpkgs.legacyPackages.aarch64-darwin; [
        python312
        nodejs_22
        ruby_3_4
      ];
    };
  };
}
```

```bash
# project/.envrc
use flake
```

______________________________________________________________________

## What Cannot Be Migrated

### Mac App Store Apps

No workaround exists. Options:

1. Use nix-darwin's `homebrew.masApps` (still uses `mas` CLI)
2. Manual installation (defeats the purpose)
3. Accept that some apps are unmanaged

### iCloud Integration

The `icloud.sh` script creates a symlink. This is macOS-specific and will
need to remain as a manual step or activation script.

### Some System Preferences

Settings that require:

- System Integrity Protection (SIP) disabled
- Accessibility permissions
- Full Disk Access

These need manual intervention or activation scripts.

### Proprietary Applications Without Packages

Apps like:

- Cursor (no nixpkgs, use homebrew cask)
- LM Studio (no nixpkgs, use homebrew cask)
- Keyboard Maestro (no nixpkgs, use homebrew cask)
- Stream Deck (no nixpkgs, use homebrew cask)

______________________________________________________________________

## Hybrid Approach (Recommended)

Given the realities of macOS, a hybrid approach is most practical:

```
nix-darwin
├── system.defaults.* → macOS preferences (what's supported)
├── homebrew.casks → GUI apps without nixpkgs
├── homebrew.masApps → Mac App Store apps
└── environment.systemPackages → some CLI tools

home-manager
├── home.packages → CLI tools
├── programs.* → shell, git, direnv, etc.
└── home.file.* → dotfiles

Remaining bash scripts
├── apps/macos/unsupported-defaults.sh → edge cases
├── apps/macos/folders.sh → folder structure
└── apps/icloud/icloud.sh → iCloud symlink
```

______________________________________________________________________

## Effort Breakdown

| Task                              | Effort     | Notes                     |
| --------------------------------- | ---------- | ------------------------- |
| Nix/nix-darwin/home-manager setup | 4-8 hours  | One-time learning curve   |
| CLI tools migration               | 4-8 hours  | Mostly straightforward    |
| Dotfiles migration                | 4-8 hours  | Convert to home-manager   |
| macOS defaults                    | 8-16 hours | Research what's supported |
| GUI apps via homebrew             | 2-4 hours  | Simple declaration        |
| Per-project dev shells            | Ongoing    | Replace asdf as needed    |
| Testing & debugging               | 8-16 hours | Inevitable issues         |
| Documentation                     | 4-8 hours  | New workflow docs         |

**Total: 40-70 hours** (1-2 weeks full-time, 2-4 weeks part-time)

______________________________________________________________________

## Decision Framework

### Migrate to Nix if

- You want atomic rollbacks for system configuration
- You manage multiple Macs and want identical setups
- You're already using Nix for development
- You enjoy learning new systems
- Reproducibility is a core value

### Keep current system if

- It's working fine and not causing pain
- You value simplicity and readability
- You don't need rollbacks
- Time is better spent elsewhere
- Mac App Store apps are critical (still need Homebrew either way)

______________________________________________________________________

## Resources

- [nix-darwin](https://github.com/LnL7/nix-darwin)
- [home-manager](https://github.com/nix-community/home-manager)
- [nix-darwin options reference](https://daiderd.com/nix-darwin/manual/index.html)
- [Zero to Nix](https://zero-to-nix.com/)
- [Nix flakes guide](https://nixos.wiki/wiki/Flakes)
- [Example macOS configs](https://github.com/search?q=darwinConfigurations&type=code)

______________________________________________________________________

## Appendix: Current Script Mapping

| Current Script             | Nix Equivalent                                 |
| -------------------------- | ---------------------------------------------- |
| `brew.sh` + Brewfile       | `homebrew.brews`, `environment.systemPackages` |
| `zsh.sh` + .zshrc          | `programs.zsh`                                 |
| `ohmyzsh.sh`               | `programs.zsh.oh-my-zsh`                       |
| `macos.sh`                 | `system.defaults.*`                            |
| `icloud.sh`                | Manual or activation script                    |
| `asdf.sh` + .tool-versions | Per-project flakes + direnv                    |
| `git.sh` + .gitconfig      | `programs.git`                                 |
| `direnv.sh`                | `programs.direnv`                              |
| `1password.sh`             | `home.file.".config/1password/ssh/agent.toml"` |
| `shellcheck.sh`            | `home.file.".config/shellcheckrc"`             |
| `markdownlint.sh`          | `home.file`                                    |
| `mdformat.sh`              | `home.packages = [ pkgs.mdformat ];`           |
| `shfmt.sh`                 | `home.file.".editorconfig"`                    |
| `ruff.sh`                  | `home.file.".config/ruff/ruff.toml"`           |
| `uv.sh`                    | `home.packages` or per-project                 |
| `claudecode.sh`            | `home.file` for dotfiles, npm global install   |
| `gemini-cli.sh`            | npm global install                             |
| `codex-cli.sh`             | homebrew cask                                  |
| `karabiner.sh`             | `home.file.".config/karabiner/karabiner.json"` |
| `folders.sh`               | Activation script or home-manager              |
