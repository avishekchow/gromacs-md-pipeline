#!/usr/bin/env bash
set -euo pipefail

echo "=== System information ==="
echo "Host: $(hostname)"
echo "OS: $(uname -s)"
echo "Kernel: $(uname -r)"
echo "Architecture: $(uname -m)"
echo

if command -v gmx >/dev/null 2>&1; then
    echo "=== GROMACS ==="
    gmx --version | sed -n '1,12p'
else
    echo "GROMACS is not available in PATH."
fi
