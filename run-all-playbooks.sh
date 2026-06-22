#!/usr/bin/env bash
# Run all playbooks/*/sync.yml in order, forwarding any arguments (e.g. --limit, --check --diff).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

for playbook in "$SCRIPT_DIR"/playbooks/*/sync.yml; do
    echo "==> Running $playbook"
    ansible-playbook "$playbook" "$@"
done
