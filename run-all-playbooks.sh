#!/usr/bin/env bash
# Run all playbooks/*/sync.yml in order, forwarding any arguments (e.g. --limit, --check --diff).
# Continues on failure so all playbooks run; exits non-zero if any failed.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

failed=()
for playbook in "$SCRIPT_DIR"/playbooks/*/sync.yml; do
    echo "==> Running $playbook"
    if ! ansible-playbook "$playbook" "$@"; then
        failed+=("$playbook")
    fi
done

if [[ ${#failed[@]} -gt 0 ]]; then
    echo ""
    echo "==> FAILED playbooks:"
    for f in "${failed[@]}"; do
        echo "    $f"
    done
    exit 1
fi
