
Say Arrr.
## Overview

This repo uses Ansible to sync a standardized development environment across remote  servers and configure local machine settings. Each tool (bash, SSH, vim, zsh, git, vscode, etc.) gets its own playbook under `playbooks/`. Secrets are encrypted with Ansible Vault (AES-256) and stored in `group_vars/**/vault.yml`.
`run-all-playbooks.sh` — discovers and runs all `playbooks/*/sync.yml` in order; forwards any CLI arguments

## Assumptions

- None of the hosts have sudo access, unless otherwise specified.
- The vault password file is `.vault_pass` in the project root (gitignored).
- The playbooks for each tool generally follow the same directory layout: `playbooks/<tool>/sync.yml` is the entry point, and any pertinent config files live as jinja2 files in `playbooks/<tool>/templates/`. 

## Playbooks
Current playbooks:
- `playbooks/bash/sync.yml` — deploys bash config files to `[uth]` hosts
- `playbooks/ssh/sync.yml` — deploys SSH config to `localhost`, generates an SSH keypair, and pushes the public key to all `[REMOTE_SERVERS]` hosts (proxy + uth); run with `--ask-pass` for initial key distribution
- `playbooks/uv/sync.yml` — installs uv and uv tools (yamllint, yamlfix) on `[uth]` hosts
- `playbooks/vscode/sync.yml` — deploys VSCode settings to `localhost`
- `playbooks/git/sync.yml` — deploys `.gitconfig` to `localhost`
- `playbooks/zsh/sync.yml` — deploys Zsh config to `[local]` hosts (macOS)

- `playbooks/claude/sync.yml` — deploys global `~/.claude/CLAUDE.md` to `[uth]` hosts
- `playbooks/docker/sync.yml` — sets up rootless Docker with NVIDIA GPU support on `[uth]` hosts; assumes prerequisites (uidmap, nvidia-container-toolkit) are already installed system-wide
- `playbooks/nodejs/install-nvm.yaml` — installs NVM on `[uth]` hosts; optionally installs Node.js versions and sets a default
- `playbooks/go/sync.yml` — installs Go to `~/.local/go`; adds `~/.local/go/bin` to PATH in `.zshrc` (macOS) or `.bashrc` (Linux); version pinned in `vars.yml`

Planned: `playbooks/vim/`

## Inventory File vs group_vars

Never define group variables in the `.ini` inventory file (e.g. `[uth:vars]`). Always use `group_vars/<group>/vars.yml` instead. Inventory file group vars have the **lowest** precedence and will be silently overridden by any `group_vars/` file — including `group_vars/all`.

## Variable Precedence Gotcha

`group_vars/all/vars.yml` has **higher** precedence than inventory file group vars (e.g. `[uth:vars]`). This means any `ansible_ssh_common_args` set in `group_vars/all` will silently clobber group-specific SSH args (like `ProxyJump`) defined in the inventory. If SSH connectivity to a group breaks, check whether `group_vars/all/vars.yml` is overriding a connection variable.

## Where to Put Variables (Ansible Docs Guidance)

- **Define each variable in one place.** Pick a location and keep it simple — don't scatter the same variable across multiple sources.
- **Use inventory / `group_vars` for geography or behavior.** Variables that describe where a host lives or what role it plays belong in inventory. Set them at the group level when possible; child groups and `host_vars` can override as needed.
- **`group_vars/all`** — site-wide defaults. **`group_vars/<location>`** — regional overrides. **`host_vars/<host>`** — individual host exceptions.
- **Role defaults** (`roles/x/defaults/main.yml`) should provide reasonable fallback values so callers don't hit undefined-variable errors; they're intentionally the lowest-precedence source.
- **Pass variables as role parameters** when you want an explicit, intentional override — this is clearer than relying on precedence order and overrides role defaults.
- **Use `--extra-vars` (`-e`)** only when you need a guaranteed override and are unsure what else might be set — it beats everything.

## Always Ensure

- Before applying any playbook, always run a dry-run first to validate it against all hosts:
  ```
  ansible-playbook -i inventory.ini playbooks/<tool>/sync.yml --check --diff
  ```
- When modifying PATH (e.g. via `lineinfile`), always cover all three shells: bash (`~/.bashrc`), zsh (`~/.zshrc`), and PowerShell (`$PROFILE`). Use separate tasks conditioned on the appropriate OS/shell.
- `backup: yes`
- `hosts` should have `target_hosts`. If I specify a group, set it as the default value alongside `target_hosts`. Default to `uth` unless the playbook is explicitly localhost-only (e.g. `playbooks/vscode/sync.yml`).
- Never include `connection: local` in playbooks, **except** `playbooks/vscode/sync.yml` which is localhost-only and requires it.
- Decouple parameters with a high probable of being manually edited by the user (e.g., list of packages to install) into a variable in an accompanying `vars.yml`.
- Any generated config files should go into a `templates` subdirectory as a jinja2 file.
- This is a personal repo — `group_vars/**/vars.yml` files are committed directly. No `.example` counterparts needed.
- Still extract sensitive values (IPs, tokens, passwords) into `group_vars/**/vars.yml` or `vault.yml` and reference via Jinja2 — never hardcode them inline in playbooks or templates.