
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
- `playbooks/uv/sync.yml` — installs uv and uv tools (yamllint, yamlfix) on `[uth]` hosts
- `playbooks/vscode/sync.yml` — deploys VSCode settings to `localhost`
- `playbooks/git/sync.yml` — deploys `.gitconfig` to `localhost`
- `playbooks/zsh/sync.yml` — deploys Zsh config to `[local]` hosts (macOS)
- `playbooks/macos/sync.yaml` — deploys macOS-specific config to `[local]` hosts (e.g. `hidutil` key-remapping LaunchAgent at `~/Library/LaunchAgents/com.local.KeyRemapping.plist`)

- `playbooks/claude/sync.yml` — deploys global `~/.claude/CLAUDE.md` to `[uth]` hosts
- `playbooks/docker/sync.yml` — sets up rootless Docker with NVIDIA GPU support on `[uth]` hosts; assumes prerequisites (uidmap, nvidia-container-toolkit) are already installed system-wide
- `playbooks/nodejs/install-nvm.yaml` — installs NVM on `[uth]` hosts; optionally installs Node.js versions and sets a default
- `playbooks/go/sync.yml` — installs Go to `~/.local/go`; symlinks `go`/`gofmt` into `~/.local/bin`; version pinned in `vars.yml`
- `playbooks/gh/sync.yml` — installs/updates GitHub CLI (`gh`) to `~/.local/bin` and manages `gh` extensions (e.g. `nektos/gh-act`); version and extension list pinned in `vars.yml`
- `playbooks/bws/sync.yml` — installs the Bitwarden Secrets Manager CLI (`bws`) to `~/.local/bin` via the official install script and drops `~/.config/shell.d/bws.sh` (exports `BWS_ACCESS_TOKEN`) and `~/.local/scripts/bws_upsert_secret.sh` (creates or updates a secret: hidden prompt or piped value, project by name/id/menu); version pinned in `vars.yml`
- `playbooks/bws/token.yml` — prompts for a bws access token and stores it in the macOS keychain (Linux: `0600` file under `~/.config/bws/`)
- `playbooks/podman/sync.yml` — deploys the Podman machine (VM) config and starts enabled `containers/<service>/` container services on `localhost`; see `playbooks/podman/vm/` (VM config templates) and `playbooks/podman/containers/forward-proxy/` (egress-filtering forward proxy, example service)
- `playbooks/k3s-argocd/sync.yaml` — bootstraps a single k3s server (traefik and servicelb disabled) via the `k3s.orchestration` roles on `[k3s_server]` and installs Argo CD with `kubernetes.core.helm`; **requires sudo** on the target. k3s, Helm and argo-cd chart versions pinned in `vars.yml`
- `playbooks/k3s-argocd/secrets.yaml` — creates Kubernetes Secrets (and their namespaces) on an existing cluster from vault variables named `<namespace>__<secret-name>` in `group_vars/k3s_server/vault.yml`; **requires sudo**; see `group_vars/k3s_server/CLAUDE.md`

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
- Every playbook must complete its `--check` dry-run without failures, including on a fresh host. Tasks that depend on an earlier task's effect (a file it downloads, a service it starts) must be skipped or guarded with `ansible_check_mode`; read-only probes (e.g. `<tool> --version`) should set `check_mode: false` so later conditions see real values.
- Only `playbooks/shell/` may touch `.bashrc` or `.zshrc`, or modify PATH. `~/.local/bin` is already on PATH via `playbooks/shell/templates/00-common.sh.j2`, so no other playbook needs to add to PATH. Install standalone binaries to `~/.local/bin` unless explicitly told otherwise.
- `backup: yes`
- `hosts` should have `target_hosts`. If I specify a group, set it as the default value alongside `target_hosts`. Never `default('uth')`; remote groups are targeted explicitly with `-e target_hosts=<group>`.
- Never include `connection: local` in playbooks, **except** `playbooks/vscode/sync.yml` which is localhost-only and requires it.
- Decouple parameters with a high probable of being manually edited by the user (e.g., list of packages to install) into a variable in an accompanying `vars.yml`.
- Any generated config files should go into a `templates` subdirectory as a jinja2 file.
- This is a personal repo — `group_vars/**/vars.yml` files are committed directly. No `.example` counterparts needed.
- Still extract sensitive values (IPs, tokens, passwords) into `group_vars/**/vars.yml` or `vault.yml` and reference via Jinja2 — never hardcode them inline in playbooks or templates.
