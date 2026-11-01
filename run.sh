#!/usr/bin/env bash
# Run playbooks/<name>/sync.yml for each named playbook, in the order given.
# Usage: ./run.sh <name>... [ansible-playbook args]
#   ./run.sh dns bash git
#   ./run.sh dns --limit pi --check --diff
# Leading arguments that don't start with "-" are playbook names; the first
# argument starting with "-" and everything after it is forwarded to
# ansible-playbook. Continues on failure; exits non-zero if any failed.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

names=()
while [[ $# -gt 0 && "$1" != -* ]]; do
    names+=("$1")
    shift
done

usage() {
    echo "Usage: $0 <name>... [ansible-playbook args]" >&2
    echo "Available playbooks:" >&2
    for dir in "$SCRIPT_DIR"/playbooks/*/; do
        [[ -f "$dir/sync.yml" ]] && echo "    $(basename "$dir")" >&2
    done
}

if [[ ${#names[@]} -eq 0 ]]; then
    usage
    exit 2
fi

# Validate every name up front so a typo doesn't fail halfway through.
for name in "${names[@]}"; do
    if [[ ! -f "$SCRIPT_DIR/playbooks/$name/sync.yml" ]]; then
        echo "Unknown playbook: $name" >&2
        usage
        exit 2
    fi
done

failed=()
for name in "${names[@]}"; do
    playbook="$SCRIPT_DIR/playbooks/$name/sync.yml"
    echo "==> Running $playbook"
    if ! ansible-playbook "$playbook" "$@"; then
        failed+=("$name")
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
