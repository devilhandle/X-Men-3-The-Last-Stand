#!/usr/bin/env bash
set -euo pipefail

# Patch the standalone build script before it clones/builds J2ME-Loader.
# Only the requested X-Men controls are enabled: D-pad, 5, 0, L and R.
python3 - <<'PY'
from pathlib import Path

p = Path('scripts/build-standalone.sh')
s = p.read_text()

# Replace the generated TYPE_XMEN layout with a compact layout that keeps every
# requested key fully on-screen. The D-pad is centered along the lower edge;
# 5 and 0 are stacked at the lower-right; L/R stay at the top corners.
start = s.index("case = '''")
end = s.index("'''\nif needle not in s:", start) + 3
case = '''case = ''' + "'''" + '''\t\t\tcase TYPE_XMEN:\n\t\t\t\t// X-Men-only controls. Never show the normal J2ME/emulator keypad.\n\t\t\t\tArrays.fill(keyScales, 1.0f);\n\t\t\t\tkeyScales[0] = 0.72f; // D-pad group\n\t\t\t\tkeyScales[1] = 0.72f; // L/R\n\t\t\t\tkeyScales[3] = 0.72f; // 5/0 (all other numeric keys remain hidden)\n\t\t\t\tfor (VirtualKey key : keypad) key.visible = false;\n\n\t\t\t\t// L and R: upper-left / upper-right.\n\t\t\t\tsetSnap(KEY_SOFT_LEFT, SCREEN, RectSnap.INT_NORTHWEST, true);\n\t\t\t\tsetSnap(KEY_SOFT_RIGHT, SCREEN, RectSnap.INT_NORTHEAST, true);\n\n\t\t\t\t// Complete four-way D-pad, centered at the lower edge so no arrow is clipped.\n\t\t\t\tsetSnap(KEY_DOWN, SCREEN, RectSnap.INT_SOUTH, true);\n\t\t\t\tsetSnap(KEY_UP, KEY_DOWN, RectSnap.EXT_NORTH, true);\n\t\t\t\tsetSnap(KEY_LEFT, KEY_UP, RectSnap.EXT_WEST, true);\n\t\t\t\tsetSnap(KEY_RIGHT, KEY_UP, RectSnap.EXT_EAST, true);\n\n\t\t\t\t// 5 and 0: both at the bottom-right, with 0 below 5.\n\t\t\t\tsetSnap(KEY_NUM0, SCREEN, RectSnap.INT_SOUTHEAST, true);\n\t\t\t\tsetSnap(KEY_NUM5, KEY_NUM0, RectSnap.EXT_NORTH, true);\n\t\t\t\tbreak;\n\t\t\tcase TYPE_NUM_ARR:\n\t\t\tdefault:'''
s = s[:start] + case + s[end:]
p.write_text(s)
PY

bash scripts/build-standalone.sh
