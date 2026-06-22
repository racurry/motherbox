# Tool ownership & responsibility

**`Homebrew`** is the de facto owner of apps, libraries, system wide tools, and global CLIs.  If a tool can be installed with `brew`, use `brew`.  Except:

- **`mise`**: use `mise` when a tool would pull in a language runtime or I need the most-up-to-date possible version.
	- `brew` managed runtimes will conflict with my intentionally installed runtimes - keep them out of brew.  Eg, `yamllint` pulls in a brew managed python, so it goes in `mise`.
	- Some tools ship updates multiple times a day.  Eg codex, gemini.  Using brew introduces lag in staying up to date.  Use `mise` for these.
- **native installs**: some things just need a native install.  Script if possible, manual download if not.  Eg, `brew` itself, `claude`.

`Mise` is the default owner of runtimes, language versions, language toolchains, and tools that execute or compile project code.  Use `mise` for everything, except for:

- `XCode` - xcode manages everything related to `swift` or building Apple apps.
- `Rust` - Rust uses `rustup`

Each language/ecosystem needs a single, consistent package manager. We want modern, fast, but reliable tools.

- Fixed list: `uv` for `python`, `pnpm` for `node`, `cargo` for `rust`
- Do not let these tools manage runtimes; packages & project environments only.  Eg, `mise` owns `python` version, `uv` owns packages.  Use `python-preference = "only-system"` in uv.

`chezmoi` is used for dotfiles, configs, and coordination scripts to manage things. Any config that can be run through chezmoi should be. Use templates to coordinate different machines across work and personal.

---

Very loosely inspired by [Sovereign Tools](https://www.shiinayane.com/series/sovereign-tools/)
