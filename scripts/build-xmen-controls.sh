#!/usr/bin/env bash
set -euo pipefail

# Patch the standalone build script before it clones/builds J2ME-Loader.
# Requested controls only: full D-pad, 5, 0, L and R.
python3 - <<'PY'
from pathlib import Path

p = Path('scripts/build-standalone.sh')
s = p.read_text()

start = s.index("case = '''")
end = s.index("\nif needle not in s:", start)

case_body = """\t\t\tcase TYPE_XMEN:
\t\t\t\t// X-Men-only controls. Never show the normal J2ME/emulator keypad.
\t\t\t\tArrays.fill(keyScales, 1.0f);
\t\t\t\tkeyScales[0] = 0.72f; // D-pad group
\t\t\t\tkeyScales[1] = 0.72f; // L/R
\t\t\t\tkeyScales[3] = 0.72f; // 5/0; other numeric keys stay hidden
\t\t\t\tfor (VirtualKey key : keypad) key.visible = false;

\t\t\t\t// L and R at the top corners.
\t\t\t\tsetSnap(KEY_SOFT_LEFT, SCREEN, RectSnap.INT_NORTHWEST, true);
\t\t\t\tsetSnap(KEY_SOFT_RIGHT, SCREEN, RectSnap.INT_NORTHEAST, true);

\t\t\t\t// Complete D-pad. Down is anchored at the bottom-center so all four arrows fit.
\t\t\t\tsetSnap(KEY_DOWN, SCREEN, RectSnap.INT_SOUTH, true);
\t\t\t\tsetSnap(KEY_UP, KEY_DOWN, RectSnap.EXT_NORTH, true);
\t\t\t\tsetSnap(KEY_LEFT, KEY_UP, RectSnap.EXT_WEST, true);
\t\t\t\tsetSnap(KEY_RIGHT, KEY_UP, RectSnap.EXT_EAST, true);

\t\t\t\t// 5 and 0 are both at the bottom-right; 0 is below 5.
\t\t\t\tsetSnap(KEY_NUM0, SCREEN, RectSnap.INT_SOUTHEAST, true);
\t\t\t\tsetSnap(KEY_NUM5, KEY_NUM0, RectSnap.EXT_NORTH, true);
\t\t\t\tbreak;
\t\t\tcase TYPE_NUM_ARR:
\t\t\tdefault:"""

replacement = 'case = ' + repr(case_body)
s = s[:start] + replacement + s[end:]
p.write_text(s)
PY

bash scripts/build-standalone.sh
