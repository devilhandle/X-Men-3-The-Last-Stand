#!/usr/bin/env bash
set -euo pipefail

# The standalone build already contains the complete X-Men-only keyboard
# integration. Keep this wrapper intentionally simple so the control patch
# cannot introduce a second, conflicting VirtualKeyboard patch.
bash scripts/build-standalone.sh
