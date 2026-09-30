#!/usr/bin/env bash
set -euo pipefail

usage() {
    echo "Usage: $0 <input-structure> [required-file ...]"
    exit 2
}

[[ $# -ge 1 ]] || usage

for file in "$@"; do
    if [[ -f "$file" ]]; then
        echo "[OK] $file"
    else
        echo "[MISSING] $file"
    fi
done
