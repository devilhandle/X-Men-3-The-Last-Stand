#!/usr/bin/env bash
set -euo pipefail

# Build from the existing no-keypad standalone script, but replace its generated
# X-Men layout with exactly the requested controls: D-pad + 5 + 0 + L + R.
python3 - <<'PY'
from pathlib import Path

p = Path('scripts/build-standalone.sh')
s = p.read_text()

start = s.index("case = '''")
end = s.index("'''\nif needle not in s:", start)

case = '''case = ''' + "'''" + '''\t\t\tcase TYPE_XMEN:\n\t\t\t\t// X-Men-only controls. Never show the normal J2ME numeric/emulator keypad.\n\t\t\t\tArrays.fill(keyScales, 1.0f);\n\t\t\t\tfor (VirtualKey key : keypad) key.visible = false;\n\n\t\t\t\t// L and R at the top-left and top-right.\n\t\t\t\tsetSnap(KEY_SOFT_LEFT, SCREEN, RectSnap.INT_NORTHWEST, true);\n\t\t\t\tsetSnap(KEY_SOFT_RIGHT, SCREEN, RectSnap.INT_NORTHEAST, true);\n\n\t\t\t\t// Four directional control buttons at the bottom-left.\n\t\t\t\tsetSnap(KEY_UP, SCREEN, RectSnap.INT_SOUTHWEST, true);\n\t\t\t\tsetSnap(KEY_LEFT, KEY_UP, RectSnap.EXT_WEST, true);\n\t\t\t\tsetSnap(KEY_RIGHT, KEY_UP, RectSnap.EXT_EAST, true);\n\t\t\t\tsetSnap(KEY_DOWN, KEY_UP, RectSnap.EXT_SOUTH, true);\n\n\t\t\t\t// 5 and 0 on the right side.\n\t\t\t\tsetSnap(KEY_NUM5, SCREEN, RectSnap.INT_EAST, true);\n\t\t\t\tsetSnap(KEY_NUM0, KEY_NUM5, RectSnap.EXT_SOUTH, true);\n\t\t\t\tbreak;\n\t\t\tcase TYPE_NUM_ARR:\n\t\t\tdefault:'''

s = s[:start] + case + s[end:]

# Use the normal arrow glyph for the up control; the requested controls are not
# the home/pause symbols from the earlier experimental layout.
s = s.replace(
    'keypad[KEY_UP] = new VirtualKey(Canvas.KEY_UP, "⌂");',
    'keypad[KEY_UP] = new VirtualKey(Canvas.KEY_UP, ARROW_UP);',
    1,
)
p.write_text(s)
PY

bash scripts/build-standalone.sh
