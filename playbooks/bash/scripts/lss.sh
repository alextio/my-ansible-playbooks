#!/usr/bin/env bash
# Usage: lss [directory]
du -h --max-depth=1 "${1:-.}" | sort -h
