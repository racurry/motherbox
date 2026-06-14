# Mother Box

All-in-one project for managing multiple macOS environments (personal and work) consistently. Setup scripts for a new Mac setup, development environment setup, overall app & tool settings, dotfiles, and a handful of convenience scripts that help with various workflows.

## Set up a new mac

1. Install command line tools: `xcode-select --install`
2. [Download 1Password](https://1password.com/downloads/mac), install, and sign in
3. Enable SSH agent: Settings → Developer → SSH Agent.
   - Accept the automated config from 1Password.
   - Check "Integrate with 1Password CLI".
4. Sign into the Mac App Store app
5. Clone: `git clone git@github.com:racurry/motherbox.git ~/code/me/motherbox`
6. Run: `cd ~/code/me/motherbox && ./run/setup.sh`

## Structure

- [apps](./apps) - Application-specific configs and setup scripts, organized by app. Some are part of the default setup path; others are opt-in apps, experiments, or notes for tools used occasionally
- [scripts](./scripts) - Standalone utilities that can be run manually. Automatically added to PATH
- [machines](./machines) - Machine-specific automation (launchd jobs, maintenance scripts)
- [lib](./lib) - Shared library functions and helpers
- [run](./run) - App-agnostic or coordination utility scripts
- [docs](./docs) - Instructions on how to manage this repository

## Testing

Tests are lightweight smoke checks for setup paths that are valuable, practical to run locally, and practical to run in CI. They live next to the code they test and are not meant to provide comprehensive unit coverage.

```bash
./run/test.sh           # Run all tests, run lint
./run/test.sh lint      # ShellCheck on all bash sources
./run/test.sh unit      # Unit tests
./run/test.sh --app brew  # Run tests for specific app only
```

## More to do

[We're never really done](./TODO.md)

## Resources

Stuff that helps

- <http://www.bresink.com/osx/TinkerTool.html>
- <https://formulae.brew.sh/>
- https://www.nerdfonts.com/
