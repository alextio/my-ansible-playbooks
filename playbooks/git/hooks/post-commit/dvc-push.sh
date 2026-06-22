#!/bin/bash
if git diff-tree --no-commit-id -r HEAD --name-only | grep -q '\.dvc$'; then
    dvc push
fi
