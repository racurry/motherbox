# Adding New Apps

This guide describes how to add a new app to the repository.

Not every app directory is part of the default `./run/setup.sh` path. `apps/`
also holds opt-in tools, experiments, occasional-use apps, and manual notes.
`run/setup.sh` is the source of truth for what gets installed and configured on
a new machine by default.

## Directory Structure

Create a new directory under `apps/`:

```text
apps/{app}/
├── README.md          # Documentation (required)
├── {app}.sh           # Main setup script (if app setup can be automated).
├── test_{app}.bats    # BATS unit tests (if applicable)
└── ...                # Config files, templates, etc.
```

## Apps Files

- `README.md`: See the [README template](readme_template.md) for the readme outline to use
- `{app}.sh`: See [bash_scripting.md](bash_scripting.md) for bash script template and conventions.
- `test_{app}.bats`: See [testing.md](../common/testing.md) for BATS test templates and patterns.

## Checklist

When adding a new app:

- [ ] Create `apps/{app}/` directory
- [ ] Create `{app}.sh` with `setup` and `install` commands based on [bash_scripting.md](bash_scripting.md)
- [ ] Implement `do_install()` if installation can be automated (e.g., `brew install`)
- [ ] Create `README.md` with contents and setup instructions based on [readme_template.md](readme_template.md)
- [ ] Create `test_{app}.bats` with basic tests _if applicable_, based on [testing.md](../common/testing.md)
- [ ] Verify `./run/test.sh lint` passes
- [ ] Verify `./run/test.sh --app {app}` passes (if tests exist)
