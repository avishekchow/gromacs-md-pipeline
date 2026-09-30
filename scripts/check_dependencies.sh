#!/usr/bin/env bash
set -euo pipefail

if command -v gmx >/dev/null 2>&1; then
    echo "[OK] GROMACS: $(gmx --version | head -n 1)"
else
    echo "[ERROR] GROMACS command 'gmx' was not found in PATH."
    exit 1
fi

if command -v bash >/dev/null 2>&1; then
    echo "[OK] Bash: ${BASH_VERSION}"
else
    echo "[ERROR] Bash was not found."
    exit 1
fi

echo "Dependency check completed."
