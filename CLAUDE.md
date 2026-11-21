
Say Arrr.
## Overview

This repo uses Ansible to sync a standardized development environment across remote  servers and configure local machine settings. Each tool (bash, SSH, vim, zsh, git, vscode, etc.) gets its own playbook under `playbooks/`. Secrets are encrypted with Ansible Vault (AES-256) and stored in `group_vars/**/vault.yml`.
`run.sh <name>...` — runs `playbooks/<name>/sync.yml` for each named playbook in order; arguments from the first `-`-prefixed one onward are forwarded to ansible-playbook

## Assumptions

- None of the hosts have sudo access, unless otherwise specified.
- The vault password file is `.vault_pass` in the project root (gitignored).
- The playbooks for each tool generally follow the same directory layout: `playbooks/<tool>/sync.yml` is the entry point, and any pertinent config files live as jinja2 files in `playbooks/<tool>/templates/`. 

## Playbooks
Current playbooks:
- `playbooks/shell/sync.yml` — deploys shell config: `.bashrc`/`.bash_profile` on non-macOS hosts, `.zshrc` on macOS, plus shared `~/.config/shell.d/00-common.sh` and `10-aliases.sh` sourced by both
- `playbooks/ssh/sync.yml` — deploys SSH config to `localhost`
- `playbooks/ssh/keypair-regen.yml` — generates an SSH keypair on `localhost` and pushes the public key to all `[REMOTE_SERVERS]` hosts (proxy + uth); run with `--ask-pass` for initial key distribution
- `playbooks/uv/sync.yml` — runs `roles/uv`: installs uv and uv tools (list in `roles/uv/defaults/main.yml`); defaults to `all:!proxy`
- `playbooks/vscode/sync.yml` — deploys VSCode settings to `localhost`
- `playbooks/git/sync.yml` — deploys `.gitconfig` to `localhost`
- `playbooks/zsh/sync.yml` — deploys Zsh config to `[local]` hosts (macOS)
- `playbooks/macos/sync.yaml` — deploys macOS-specific config to `[local]` hosts (e.g. `hidutil` key-remapping LaunchAgent at `~/Library/LaunchAgents/com.local.KeyRemapping.plist`)

- `playbooks/claude-code/sync.yml` — runs `roles/claude_code`: deploys global `~/.claude/CLAUDE.md` and installs or updates Claude Code; defaults to `all:!proxy`
- `playbooks/docker/sync.yml` — runs `roles/docker`: sets up rootless Docker with NVIDIA GPU support; defaults to `all:!proxy`; assumes prerequisites (uidmap, nvidia-container-toolkit) are already installed system-wide
- `playbooks/nodejs/sync.yml` — runs `roles/nodejs`: installs NVM, Node.js versions, a default version and global npm packages (all in `roles/nodejs/defaults/main.yml`); defaults to `all:!proxy`
- `playbooks/go/sync.yml` — runs `roles/go`: installs Go to `~/.local/go`; symlinks `go`/`gofmt` into `~/.local/bin`; version pinned in `roles/go/defaults/main.yml`
- `playbooks/gh/sync.yml` — runs `roles/gh`: installs/updates GitHub CLI (`gh`) to `~/.local/bin` and manages `gh` extensions (e.g. `nektos/gh-act`); version and extension list pinned in `roles/gh/defaults/main.yml`
- `playbooks/bws/sync.yml` — runs `roles/bws` (installs the Bitwarden Secrets Manager CLI `bws` to `~/.local/bin` via the official install script and drops `~/.config/shell.d/bws.sh`, which exports `BWS_ACCESS_TOKEN`), then deploys `~/.local/scripts/bws_upsert_secret.sh` (creates or updates a secret: hidden prompt or piped value, project by name/id/menu) and imports `token.yml` and `package-skill.yml`; version, keychain service and token file in `roles/bws/defaults/main.yml`
- `playbooks/bws/token.yml` — prompts for a bws access token and stores it in the macOS keychain (Linux: `0600` file under `~/.config/bws/`); reads its settings from `roles/bws/defaults/main.yml`
- `playbooks/podman/sync.yml` — deploys the Podman machine (VM) config and starts enabled `containers/<service>/` container services on `localhost`; see `playbooks/podman/vm/` (VM config templates) and `playbooks/podman/containers/forward-proxy/` (egress-filtering forward proxy, example service)
- `playbooks/k3s-argocd/sync.yaml` — bootstraps a single k3s server (traefik and servicelb disabled) via the `k3s.orchestration` roles on `[k3s_server]` and installs Argo CD with `kubernetes.core.helm` only if it isn't already running (after bootstrap, Argo CD manages itself from `03-argocd-kubernetes`, so later runs leave it alone); **requires sudo** on the target. k3s, Helm and argo-cd chart versions pinned in `vars.yml`
- `playbooks/k3s-argocd/secrets.yaml` — creates Kubernetes Secrets (and their namespaces) on an existing cluster from vault variables named `<namespace>__<secret-name>` in `group_vars/k3s_server/vault.yml`; **requires sudo**; see `group_vars/k3s_server/CLAUDE.md`

Planned: `playbooks/vim/`

## Shared roles

Roles are for setting up bare-metal hosts (the Mac, a Windows laptop, the servers). Dev containers keep their own setup in their repo's `.devcontainer/`; don't point them at these roles.

Install-a-tool playbooks are roles: the tasks live in `roles/<name>/` (on `roles_path` via `ansible.cfg`), and `playbooks/<tool>/sync.yml` is a thin wrapper that sets the default hosts and runs the role, so `./run.sh <tool>` still works. Config deployers for one machine (`vscode`, `macos`, `zsh`, `ssh`, `git`, `shell`) and multi-play orchestration (`ssh/keypair-regen.yml`, `k3s-argocd`) stay plain playbooks.

- Use snake_case role names (`claude_code`, `podman_docker`).
- User-editable settings (pinned versions, package lists) go in `roles/<name>/defaults/main.yml` instead of a playbook `vars.yml`, so every playbook that includes the role sees them. Values derived from them (download URLs, arch names) go in `roles/<name>/vars/main.yml`.
- Templates go in `roles/<name>/templates/`.
- When a role needs another one first, list it in `roles/<name>/meta/main.yml`.

Current roles: `bws`, `claude_code`, `docker`, `gh`, `go`, `nodejs`, `podman_docker`, `uv`.

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
- Every playbook must complete its `--check` dry-run without failures, including on a fresh host. Tasks that depend on an earlier task's effect (a file it downloads, a service it starts) must be skipped or guarded with `ansible_check_mode`; read-only probes (e.g. `<tool> --version`) should set `check_mode: false` so later conditions see real values.
- Only `playbooks/shell/` may touch `.bashrc` or `.zshrc`, or modify PATH. `~/.local/bin` is already on PATH via `playbooks/shell/templates/00-common.sh.j2`, so no other playbook needs to add to PATH. Install standalone binaries to `~/.local/bin` unless explicitly told otherwise.
- `backup: yes`
- `hosts` should have `target_hosts`. If I specify a group, set it as the default value alongside `target_hosts`. Never `default('uth')`; remote groups are targeted explicitly with `-e target_hosts=<group>`.
- Never include `connection: local` in playbooks, **except** `playbooks/vscode/sync.yml` which is localhost-only and requires it.
- Decouple parameters with a high probable of being manually edited by the user (e.g., list of packages to install) into a variable in an accompanying `vars.yml` (for a role, `roles/<name>/defaults/main.yml`; see Shared roles).
- Any generated config files should go into a `templates` subdirectory as a jinja2 file.
- This is a personal repo — `group_vars/**/vars.yml` files are committed directly. No `.example` counterparts needed.
- Still extract sensitive values (IPs, tokens, passwords) into `group_vars/**/vars.yml` or `vault.yml` and reference via Jinja2 — never hardcode them inline in playbooks or templates.
