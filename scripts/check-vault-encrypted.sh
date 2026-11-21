#!/usr/bin/env bash
# Fail if any vault.yml is committed in plain text.
set -euo pipefail
fail=0
while IFS= read -r f; do
  if ! head -n1 "$f" | grep -q '^\$ANSIBLE_VAULT;'; then
    echo "::error file=$f::$f is not encrypted with ansible-vault"
    fail=1
  fi
done < <(git ls-files '*vault.yml' '*vault.yaml')
exit $fail
