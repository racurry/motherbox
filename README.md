# Mother Box

![ping](docs/_assets/motherbox.png)

Utility drawer for managing my computers. It includes scripts, notes, configurations, and other errata that helps me set up new machines, maintain existing ones, and work the way I like to work.

## structure

```text
.
|-- mother        # script for managing motherbox
|-- docs/         # info, instructions, references
|-- home/         # chezmoi managed files
|-- scripts/
|   |-- _lib/     # library code used by other scripts, separated by language
|   |-- apps/     # app-specific scripts
|   |-- bin/      # utilities added to PATH for global use
|   `-- utils/    # utility scripts that I don't want or need globally
`-- phantom-zone/ # cold storage for configs, project-specific stuff, or apps
                  # i am not using now, but want to bring back
```

## new mac

1. Install command line tools: `xcode-select --install`
2. [Download 1Password](https://1password.com/downloads/mac), install, and sign in
3. Enable SSH agent: Settings → Developer → SSH Agent.
   - Accept the automated config from 1Password.
   - Check "Integrate with 1Password CLI".
4. Sign into the Mac App Store app
5. Clone: `git clone git@github.com:racurry/motherbox.git ~/code/me/motherbox`
6. Run: `cd ~/code/me/motherbox && ./mother`

## words

- [responsibility](docs/tool-responsibility.md): what tool should own what function.  apps -> brew, languages -> mise, configs -> chezmoi
- [project tools](docs/project-tools.md): how to do a project
- [apps notes](docs/apps-notes.md): specific notes & instructions for various apps
