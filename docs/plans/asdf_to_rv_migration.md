# Migration Plan: asdf to rv for Ruby

Replace asdf with rv for Ruby version and gem management while keeping asdf for Node.js (and Python, if not already migrated to uv).

______________________________________________________________________

## Recommendation: Wait

> **Last reviewed**: 2025-12-01

**TL;DR**: Don't migrate yet. rv is too new and incomplete for production use.

### Why wait?

| Factor              | Assessment                                                           |
| ------------------- | -------------------------------------------------------------------- |
| Maturity            | v0.2.x (October 2025), described as "early release"                  |
| Ruby support        | Only Ruby 3.2+ with precompiled binaries; older versions unsupported |
| Gem management      | Planned but not fully implemented                                    |
| Bundler replacement | Not yet complete                                                     |
| Platform support    | macOS 14+, limited Linux (glibc 2.35+)                               |
| Risk                | High - core features still being built                               |

### Do this instead

Keep asdf for Ruby. The compile time for Ruby (5-10 minutes) happens rarely (new Ruby releases, new machines). The real pain point - gem conflicts and bundler weirdness - isn't solved by rv yet.

If you want faster Ruby installs today:

- Use `ruby-build`'s binary builds when available
- Accept the occasional compile as the cost of stability

### What about scripts/ scripts?

The Ruby scripts in `scripts/` (`ocrify`, `filename_fixer`, `backgroundify`, etc.) only use stdlib:

```ruby
require 'fileutils'
require 'shellwords'
```

No external gem dependencies = **no benefit from rv**. These scripts run fine on any Ruby 2.0+.

| rv Feature         | Useful for scripts/? | Why                      |
| ------------------ | -------------------- | ------------------------ |
| Fast Ruby install  | No                   | You install Ruby rarely  |
| Gem isolation      | No                   | No gems to isolate       |
| `rv tool run`      | No                   | Not using Ruby CLI tools |
| Inline script deps | No                   | No deps needed           |

Compare with `splitpdf`, which *does* benefit from uv because it has an external dependency:

```python
#!/usr/bin/env -S uv run --script
# /// script
# dependencies = ["pypdf>=4.0.0"]
# ///
```

**If** you wrote a Ruby script needing gems (e.g., `nokogiri` for HTML parsing), rv's inline metadata would be useful. See the appendix for what that might look like.

### Revisit when

- rv reaches v1.0 with stable gem management
- rv's `Gemfile` / `Gemfile.lock` handling matches Bundler
- rv supports Ruby 3.1 and earlier (for legacy projects)
- direnv has native `use rv` support
- The Ruby community has battle-tested it for 6+ months

### If you decide to proceed anyway

The rest of this document provides a migration plan. The tooling is promising but incomplete. Expect rough edges and missing features.

______________________________________________________________________

## Executive Summary

| Aspect            | Current (asdf)                   | Target (rv)                |
| ----------------- | -------------------------------- | -------------------------- |
| Ruby version file | `.tool-versions`                 | `.ruby-version`            |
| Version source    | asdf-ruby plugin (compiles)      | Precompiled binaries       |
| Gem install       | `gem install` / `bundle install` | `rv add` / `rv install`    |
| Global tools      | `gem install --user-install`     | `rv tool install`          |
| Run one-off tools | N/A                              | `rv tool run` (like `uvx`) |
| Script deps       | Gemfile                          | Inline metadata (planned)  |
| direnv hook       | `use asdf`                       | `use rv` (custom)          |

**Key advantage**: rv installs Ruby 3.2+ in under 3 seconds using precompiled binaries, eliminating 5-40 minute compile times. It aims to unify Ruby version management, gem management, and tool execution like uv does for Python.

______________________________________________________________________

## Key Concept: No Shims (Different Model)

Unlike asdf, rv does **not** use shims. This has important implications:

| Aspect            | asdf                                          | rv                                          |
| ----------------- | --------------------------------------------- | ------------------------------------------- |
| How `ruby` works  | Shim intercepts, redirects to correct version | Shell integration activates correct version |
| PATH requirement  | asdf shims dir on PATH                        | rv-managed Ruby bin dir on PATH             |
| Version switching | Automatic per-directory via `.tool-versions`  | Shell hook + `.ruby-version`                |

**After migration**, running `ruby` directly uses whatever rv's shell hook has activated. The shell integration reads `.ruby-version` files and adjusts the environment.

______________________________________________________________________

## What rv Replaces

rv is designed to replace multiple tools:

| Current Tool                 | rv Equivalent                       | Status         |
| ---------------------------- | ----------------------------------- | -------------- |
| asdf (Ruby plugin)           | `rv ruby install`                   | Working        |
| ruby-build                   | Built-in precompiled binaries       | Working        |
| rbenv/chruby                 | `rv` shell integration              | Working        |
| Bundler                      | `rv install`, `rv add`, `rv remove` | In development |
| RubyGems                     | Built-in gem management             | In development |
| `gem install` (global tools) | `rv tool install`                   | Working        |

______________________________________________________________________

## Phase 1: Preparation

### 1.1 Create `apps/rv/` Directory

```
apps/rv/
├── rv.sh              # Setup script
├── .ruby-version      # Global Ruby version spec
├── use_rv.sh          # direnv library
├── README.md
└── test_rv.bats
```

### 1.2 Add rv to Brewfile

```ruby
# apps/brew/Brewfile
brew "rv"  # Note: Verify this is available - may need tap or direct install
```

**Fallback installation** (if not in Homebrew):

```bash
# Direct from releases
curl -fsSL https://github.com/spinel-coop/rv/releases/latest/download/rv-$(uname -s)-$(uname -m) -o /usr/local/bin/rv
chmod +x /usr/local/bin/rv
```

### 1.3 Document Current Ruby Usage

Before migrating, audit where Ruby is used:

| Location                   | Purpose           | Migration Impact        |
| -------------------------- | ----------------- | ----------------------- |
| `apps/asdf/.tool-versions` | Global Ruby 3.4.4 | Move to `.ruby-version` |
| `apps/asdf/.default-gems`  | Auto-install gems | Use `rv tool install`   |
| Ruby projects              | Development       | Update `.envrc` files   |

______________________________________________________________________

## Phase 2: Create rv App

### 2.1 `apps/rv/rv.sh`

```bash
#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../../lib/bash/common.sh"

APP_NAME="rv"

show_help() {
    cat <<EOF
Usage: $0 [COMMAND]

Manage rv Ruby version and gem management.

Commands:
    setup       Run full setup (install Ruby, configure shell)
    help        Show this help message
EOF
}

link_config_files() {
    print_heading "Link rv config files"

    # Global Ruby version
    link_home_dotfile "${SCRIPT_DIR}/.ruby-version" "${APP_NAME}"
}

install_ruby() {
    print_heading "Install Ruby via rv"

    require_command rv

    # Read version from .ruby-version
    local version
    version=$(cat "${SCRIPT_DIR}/.ruby-version")

    log_info "Installing Ruby ${version}"
    rv ruby install "${version}"
}

setup_shell_integration() {
    print_heading "Setup rv shell integration"

    # rv requires shell integration for automatic version switching
    # This is handled in .zshrc - just verify it works
    if command -v rv >/dev/null 2>&1; then
        log_info "rv is available in PATH"
    else
        log_warn "rv not found - ensure it's installed via Homebrew"
    fi
}

setup_direnv_lib() {
    print_heading "Setup direnv rv integration"

    local direnv_lib_dir="${HOME}/.config/direnv/lib"
    mkdir -p "${direnv_lib_dir}"

    ln -sf "${SCRIPT_DIR}/use_rv.sh" "${direnv_lib_dir}/use_rv.sh"
    log_info "Linked use_rv.sh to direnv lib"
}

do_setup() {
    link_config_files
    setup_shell_integration
    install_ruby
    setup_direnv_lib
}

main() {
    case "${1:-}" in
        setup) do_setup ;;
        help|--help|-h|"") show_help ;;
        *) log_warn "Unknown: $1"; show_help; exit 1 ;;
    esac
}

main "$@"
```

### 2.2 `apps/rv/.ruby-version`

```
3.4.4
```

### 2.3 `apps/rv/use_rv.sh` (direnv integration)

```bash
# ~/.config/direnv/lib/use_rv.sh
# Usage in .envrc: use rv

use_rv() {
    # Watch relevant files for changes
    watch_file .ruby-version
    watch_file Gemfile
    watch_file Gemfile.lock

    # Check for .ruby-version
    if [[ -f .ruby-version ]]; then
        local version
        version=$(cat .ruby-version)

        # Ensure the Ruby version is installed
        if ! rv ruby list 2>/dev/null | grep -q "${version}"; then
            log_status "Installing Ruby ${version} via rv"
            rv ruby install "${version}"
        fi

        # Get the path to this Ruby version's bin directory
        # Note: This may need adjustment based on rv's actual installation paths
        local ruby_bin
        ruby_bin=$(rv ruby which "${version}" 2>/dev/null || true)

        if [[ -n "${ruby_bin}" ]]; then
            PATH_add "$(dirname "${ruby_bin}")"
        fi
    fi

    # If Gemfile exists, sync dependencies (when rv supports this)
    # if [[ -f Gemfile.lock ]]; then
    #     log_status "Syncing gems (Gemfile.lock)"
    #     rv install --frozen 2>/dev/null || rv install
    # elif [[ -f Gemfile ]]; then
    #     log_status "Syncing gems (Gemfile)"
    #     rv install 2>/dev/null || true
    # fi
}
```

**Note**: The direnv integration above is speculative. rv's exact commands for querying Ruby paths may differ. Adjust based on actual rv behavior.

______________________________________________________________________

## Phase 3: Update asdf Configuration

### 3.1 Modify `apps/asdf/.tool-versions`

Remove Ruby, keep Node.js (and Python if not migrated):

```diff
  python 3.12.5
- ruby 3.4.4
  nodejs 24.1.0
```

### 3.2 Remove Ruby-specific Files

Delete or archive:

- `apps/asdf/.default-gems` (migrate to `rv tool install` calls)

### 3.3 Update `apps/asdf/asdf.sh`

Remove Ruby-specific environment variable handling:

```diff
  install_runtimes() {
      print_heading "Install asdf runtimes"
      require_command asdf
      log_info "Running 'asdf install'"
-     unset ASDF_RUBY_VERSION ASDF_NODEJS_VERSION ASDF_PYTHON_VERSION
+     unset ASDF_NODEJS_VERSION ASDF_PYTHON_VERSION
      asdf install
  }
```

Also remove linking of `.default-gems`:

```diff
  link_config_files() {
      print_heading "Link asdf config files"
      link_home_dotfile "${SCRIPT_DIR}/.tool-versions" "${APP_NAME}"
      link_home_dotfile "${SCRIPT_DIR}/.asdfrc" "${APP_NAME}"
-     link_home_dotfile "${SCRIPT_DIR}/.default-gems" "${APP_NAME}"
      link_home_dotfile "${SCRIPT_DIR}/.default-npm-packages" "${APP_NAME}"
      link_home_dotfile "${SCRIPT_DIR}/.default-python-packages" "${APP_NAME}"
  }
```

______________________________________________________________________

## Phase 4: Update Shell Configuration

### 4.1 Modify `apps/zsh/.zshrc`

Replace asdf Ruby handling with rv:

```bash
# ============================================================================
# PACKAGE MANAGERS & TOOL SETUP
# ============================================================================

# Homebrew setup
eval "$(/opt/homebrew/bin/brew shellenv)"
export BREW_PREFIX=$(brew --prefix)

# rv for Ruby version management (before asdf)
if command -v rv >/dev/null 2>&1; then
    eval "$(rv init zsh)"
fi

# asdf for Node.js (and Python if not using uv)
. $BREW_PREFIX/opt/asdf/libexec/asdf.sh
fpath=(${ASDF_DIR}/completions $fpath)
```

**Shell integration options** (rv supports multiple shells):

- zsh: `eval "$(rv init zsh)"`
- bash: `eval "$(rv init bash)"`
- fish: `rv init fish | source`

### 4.2 Ruby Aliases (Optional)

```bash
# If you want bundle-like shortcuts
alias be="rv run bundle exec"  # When rv supports bundler
```

______________________________________________________________________

## Phase 5: Update Agent Rules

### 5.1 Modify `apps/claudecode/AGENTS.global.md`

```diff
  # Rules for Coding Agents

- - **Runtime management**: Use `asdf` for runtime version management (never install runtimes via apt/brew/etc).  If asdf is not installed, ask for guidance.
+ - **Runtime management**: Use `rv` for Ruby version management and `asdf` for Node.js/Python. Never install runtimes via apt/brew/etc.
  - **Project environment**: Use `direnv` to manage project environments (venvs, PATH, env vars, etc.). Create `.envrc` if needed. If direnv is not installed, ask for guidance.
- - **Package management**: For asdf-managed runtimes (node/python/ruby/etc), install packages locally to the project; never install globally
+ - **Package management**: Use `rv` for Ruby gems, `uv` for Python packages. For node, install packages locally to the project; never install globally.

+ ## Ruby rules
+
+ - **Version management**: Use `rv` for Ruby version management. Use `.ruby-version` files for project-specific versions.
+ - **Gem management**: Use `rv install` for project dependencies (reads Gemfile). Use `rv tool install` for global CLI tools.
+ - **Running tools**: Use `rv tool run` to run Ruby CLI tools without installing them globally.
+ - **direnv integration**: Configure `.envrc` with `use rv` to integrate with direnv.
```

______________________________________________________________________

## Phase 6: Update Setup Orchestration

### 6.1 Modify `run/setup.sh`

Add rv setup after brew, before asdf:

```diff
  print_heading "Dev Tools"
+ run_app_setup rv     # Ruby version management
  run_app_setup asdf   # Node.js (and Python if not using uv)
  run_app_setup git
  run_app_setup direnv
```

**Order rationale**: rv comes before asdf to ensure Ruby is available early. asdf now only handles Node.js (and Python if not migrated to uv).

______________________________________________________________________

## Phase 7: Migration Execution

### 7.1 Pre-Migration Checklist

- [ ] Backup current `.tool-versions`: `cp ~/.tool-versions ~/.tool-versions.bak`
- [ ] Note any globally installed gems: `gem list`
- [ ] List projects with `.envrc` files using `use asdf`
- [ ] Verify rv is available: `brew info rv` or check releases page

### 7.2 Execution Steps

```bash
# 1. Install rv (if not via Homebrew)
# Check https://github.com/spinel-coop/rv/releases for latest

# 2. Create the apps/rv directory and files (as described above)

# 3. Run rv setup
./apps/rv/rv.sh setup

# 4. Verify Ruby is available via rv
rv ruby list
ruby --version  # Should show rv-managed version

# 5. Update asdf config (remove Ruby)
# Edit apps/asdf/.tool-versions manually

# 6. Remove asdf Ruby plugin
asdf plugin remove ruby

# 7. Update shell config
# Edit apps/zsh/.zshrc as described

# 8. Reinstall asdf runtimes (Node.js only now)
./apps/asdf/asdf.sh setup

# 9. Update direnv
./apps/direnv/direnv.sh setup

# 10. Reload shell
source ~/.zshrc
```

### 7.3 Project Migration

For each Ruby project currently using asdf:

```bash
cd /path/to/project

# Create .ruby-version if it doesn't exist
# (rv reads .tool-versions too, but .ruby-version is preferred)
grep ruby .tool-versions | awk '{print $2}' > .ruby-version

# Update .envrc
# Old: use asdf
# New: use rv

# Or for mixed projects (Node.js + Ruby):
# use asdf  # for Node.js
# use rv    # for Ruby

# Allow the new .envrc
direnv allow

# Reinstall gems (when rv supports bundler)
# rv install
# For now, fall back to bundler:
bundle install
```

______________________________________________________________________

## Phase 8: Verification

### 8.1 System Checks

```bash
# Ruby managed by rv
rv ruby list
ruby --version
which ruby

# Node.js still managed by asdf
asdf current nodejs

# Global tools work
rv tool run rubocop --version
```

### 8.2 Run Tests

```bash
./run/test.sh
```

### 8.3 Test Project Workflows

```bash
# Test a Ruby project
cd ~/workspace/some-ruby-project
direnv allow
ruby --version  # Should match .ruby-version
bundle check    # Dependencies should be satisfied
```

______________________________________________________________________

## Rollback Plan

If issues arise:

```bash
# Restore asdf Ruby
asdf plugin add ruby
echo "ruby 3.4.4" >> ~/.tool-versions
asdf install ruby 3.4.4

# Restore shell config
# Remove rv init line from .zshrc
# Ensure asdf sources Ruby again

# Restore old .envrc files
# Change "use rv" back to "use asdf"
```

______________________________________________________________________

## Current Limitations (as of v0.2.x)

| Feature                      | Status         | Workaround                      |
| ---------------------------- | -------------- | ------------------------------- |
| Ruby 3.1 and earlier         | Not supported  | Use asdf for legacy projects    |
| Full Bundler replacement     | In development | Continue using `bundle install` |
| Gemfile.lock generation      | In development | Continue using `bundle`         |
| Native extension compilation | Limited        | May need dev tools installed    |
| musl libc (Alpine)           | Not supported  | Use glibc-based containers      |
| Windows                      | Not supported  | N/A for this setup              |

______________________________________________________________________

## Decision Points

### Q1: Keep asdf at all?

**Recommendation**: Yes, for Node.js. rv only handles Ruby.

If you eventually want to eliminate asdf entirely:

- Node.js: Consider `fnm` or `volta`
- Python: Already covered by `uv` (see companion migration doc)
- Or wait for `mise` to mature as a unified replacement

### Q2: When rv fully replaces Bundler?

**Current state**: Use Bundler alongside rv. rv manages Ruby versions; Bundler manages gems.

**Future state**: When rv's gem management matures, you can:

```bash
# Instead of:
bundle install
bundle exec rspec

# Use:
rv install
rv run rspec
```

### Q3: Global Ruby tools?

**Recommendation**: Use `rv tool install` for CLI tools you use everywhere:

```bash
# One-off execution (no install)
rv tool run rubocop myfile.rb

# Persistent install
rv tool install rubocop
rv tool install solargraph
```

______________________________________________________________________

## Files Changed Summary

| File                               | Action                                    |
| ---------------------------------- | ----------------------------------------- |
| `apps/rv/` (new directory)         | Create                                    |
| `apps/rv/rv.sh`                    | Create                                    |
| `apps/rv/.ruby-version`            | Create                                    |
| `apps/rv/use_rv.sh`                | Create                                    |
| `apps/rv/README.md`                | Create                                    |
| `apps/asdf/.tool-versions`         | Remove `ruby` line                        |
| `apps/asdf/.default-gems`          | Delete                                    |
| `apps/asdf/asdf.sh`                | Remove Ruby env var, `.default-gems` link |
| `apps/zsh/.zshrc`                  | Add rv init, keep asdf for Node.js        |
| `apps/claudecode/AGENTS.global.md` | Update rules                              |
| `run/setup.sh`                     | Add `run_app_setup rv`                    |
| `apps/direnv/README.md`            | Add rv usage docs                         |
| `apps/brew/Brewfile`               | Add `rv` (when available)                 |

______________________________________________________________________

## Comparison: rv vs Other Ruby Version Managers

| Feature              | asdf               | rbenv              | chruby             | rv                    |
| -------------------- | ------------------ | ------------------ | ------------------ | --------------------- |
| Install speed        | Minutes (compiles) | Minutes (compiles) | Minutes (compiles) | Seconds (precompiled) |
| Ruby 3.2+            | Yes                | Yes                | Yes                | Yes                   |
| Ruby 3.1 and earlier | Yes                | Yes                | Yes                | No                    |
| Gem management       | No (use Bundler)   | No (use Bundler)   | No (use Bundler)   | Yes (in development)  |
| Tool isolation       | No                 | No                 | No                 | Yes (`rv tool run`)   |
| Multi-language       | Yes                | No                 | No                 | No                    |
| Shims                | Yes                | Yes                | No                 | No                    |
| Written in           | Bash               | Bash/Ruby          | Shell              | Rust                  |

______________________________________________________________________

## Appendix: Inline Script Metadata (Speculative)

rv aims to support inline script metadata similar to uv's PEP 723 support. The exact syntax is **not yet documented**, but based on rv's uv inspiration, it will likely look something like this:

### Speculative rv inline syntax

```ruby
#!/usr/bin/env rv run
# /// script
# ruby = ">=3.2"
# dependencies = [
#   "nokogiri ~> 1.16",
#   "httparty ~> 0.21",
# ]
# ///

require 'nokogiri'
require 'httparty'

# Fetch and parse a webpage
response = HTTParty.get('https://example.com')
doc = Nokogiri::HTML(response.body)
puts doc.title
```

### How it would work

```bash
# Just run it - rv handles Ruby version and gem installation
./scrape_example.rb

# Or explicitly via rv
rv run scrape_example.rb
```

### Comparison with current approaches

| Approach               | Files Needed                     | Pros                     | Cons                            |
| ---------------------- | -------------------------------- | ------------------------ | ------------------------------- |
| **rv inline** (future) | 1 script                         | Self-contained, portable | Not yet implemented             |
| **Bundler inline**     | 1 script                         | Works today              | Slower, no Ruby version pinning |
| **Traditional**        | script + Gemfile + .ruby-version | Standard approach        | 3 files for simple script       |

### Bundler inline (works today)

For comparison, Bundler already supports inline gems, but it's slower and doesn't pin Ruby version:

```ruby
#!/usr/bin/env ruby
require 'bundler/inline'

gemfile do
  source 'https://rubygems.org'
  gem 'nokogiri', '~> 1.16'
  gem 'httparty', '~> 0.21'
end

require 'nokogiri'
require 'httparty'

response = HTTParty.get('https://example.com')
doc = Nokogiri::HTML(response.body)
puts doc.title
```

**Downsides of Bundler inline:**

- Slower (resolves deps on every run unless cached)
- No Ruby version specification
- Verbose `gemfile do` block syntax

When rv's inline metadata is implemented, it should combine the best of both: fast cached installs like uv + Ruby version pinning + clean metadata syntax.

______________________________________________________________________

## References

- [rv GitHub Repository](https://github.com/spinel-coop/rv)
- [rv: A New Kind of Ruby Management Tool](https://andre.arko.net/2025/08/25/rv-a-new-kind-of-ruby-management-tool/) - Introduction blog post
- [rv: A Ruby Manager for the Future](https://andre.arko.net/2025/09/30/rv-a-ruby-manager-for-the-future/) - Technical details
- [rv on Socket.dev](https://socket.dev/blog/rv-is-a-new-rust-powered-ruby-version-manager-inspired-by-uv) - Community coverage
- [direnv Ruby documentation](https://direnv.net/docs/ruby.html) - For custom integration patterns
