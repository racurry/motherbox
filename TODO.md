# TODO

Stuff to add to this setup

## Agent workflow

For any todo in `Ready to work`, For every todo, use a sub-agent. Each agent should read the entire codebase to fully understand the context of the todo. If it is
clear what the problem and solution is, use `gh` to open an issue in <https://github.com/racurry/motherbox> using gh. Add enough
detail of the problem, solution, and actions to take in the issue so that an AI agent can implement the solution.
\
If it is not clear, the subagent should return to the main agent a list of clarifying questions. The main agent should add sub
bullets asking the clarifying questions.

## Ready

- [ ] Review VS Code sync settings - configure what syncs vs stays machine-specific (paths like openscad shouldn't sync)
- [ ] Get mcp logic set up for gemini, codex
- [ ] https://github.com/dandavison/delta
- [ ] I added a markdown config to .editorconfig - how do we make sure it isn't only part of shfmt?
- [ ] Figure out if there is a way to set download & setup ultimate 2 bluetooth software: https://app.8bitdo.com/
- [ ] Can I create a controller setting and store the config here in this repo?
- [ ] Add app: dropover


## Apps to test:
- [ ] https://github.com/ajeetdsouza/zoxide
- [ ] https://github.com/Aloxaf/fzf-tab
- [ ] https://ohmyposh.dev/

## Icebox

- [ ] Split the Brewfile up - Allow brew to install mas, and then have another script check for mas before calling mas install against the Brewfile.
- [ ] Think about update strategies for installed apps
- [ ] Can I make more complex settings with an applescript?
- [ ] Audit my system settings and see what I can automate
- [ ] Pull claude code settings out into a standalone repo; this repo will need to pull that repo down and set it up
- [ ] Fucking fix vscode's tab completion!!!
- [ ] Add extension syncing to Cursor (VS Code done via Brewfile)
- [ ] How do I set up manual set up in a clean way? Each app could have a manual_setep.md file. Can I transclude it into readme?
- [ ] https://github.com/catppuccin/bat
- [ ] What is my arc replacement?
