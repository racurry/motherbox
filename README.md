# Mother Box

All-in-one project for managing multiple macOS environments (personal and work) consistently. Setup scripts for a new Mac setup, development environment setup, overall app & tool settings, dotfiles, and a handful of convenience scripts that help with various workflows.

## Set up a new mac

1. Install command line tools: `xcode-select --install`
2. [Download 1Password](https://1password.com/downloads/mac), install, and sign in
3. Enable SSH agent: Settings → Developer → SSH Agent.
   - Accept the automated config from 1password.
4. Clone: `git clone git@github.com:racurry/motherbox.git ~/code/me/motherbox`
5. Run: `cd ~/code/me/motherbox && ./run/setup.sh`

## Structure

- [apps](./apps) - Application-specific configs and setup scripts, organized by app. Each app has its own directory with config files & setup scripts
- [scripts](./scripts) - Standalone utilities that can be run manually. Automatically added to PATH
- [machines](./machines) - Machine-specific automation (launchd jobs, maintenance scripts)
- [lib](./lib) - Shared library functions and helpers
- [run](./run) - App-agnostic or coordination utility scripts
- [docs](./docs) - Instructions on how to manage this repository

## Testing

Tests are distributed throughout the repository, co-located with the code they test.

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
