#!/usr/bin/env bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source ${ASHURA_VIRTUAL_ENV:-$HOME/.local/state/quickshell/.venv}/bin/activate
"$SCRIPT_DIR/find_regions.py" "$@"
deactivate
