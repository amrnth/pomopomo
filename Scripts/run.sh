#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
"$SCRIPT_DIR/bundle.sh"
open "$SCRIPT_DIR/../build/Pomopomo.app"
