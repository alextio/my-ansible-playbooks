# Bash Playbook

Deploys bash config files (`.bashrc`, `.bash_profile`, `.bash_aliases`) and standalone helper scripts to remote hosts.

## Adding New Commands

**Prefer `scripts/` over inline functions in `.bash_aliases.j2`.**

If a command can be written as a self-contained script — it doesn't need to modify the calling shell's environment (no `cd` that must stick, no exports that must persist to the parent) — put it in `scripts/` as its own file and register it in `vars.yml` under `bash_scripts`.

Scripts are deployed to `~/.local/scripts/<name>` and available via PATH tab completion in any new shell without sourcing.

### Checklist for a new script

- Named `scripts/<command-name>.sh`
- Starts with `#!/usr/bin/env bash`
- Uses `exit 1` (not `return 1`) for error exits
- No `local` declarations at the top level — assign variables directly

### When to use `.bash_aliases.j2` instead

- The command must run in the current shell context (e.g., `cd` wrappers, environment variable setters)
- It's a one-liner alias
