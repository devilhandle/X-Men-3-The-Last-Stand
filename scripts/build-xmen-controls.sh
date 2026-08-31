#!/usr/bin/env bash
set -euo pipefail

# Build the standalone game with a dedicated X-Men control layout.
python3 - <<'PY'
from pathlib import Path
import re

p = Path('scripts/build-standalone.sh')
s = p.read_text()

s = s.replace(
    'private static final int TYPE_ARROWS = 6;',
    'private static final int TYPE_ARROWS = 6;\n\tprivate static final int TYPE_XMEN = 7;',
    1,
)

block = r'''\t\t\tcase TYPE_XMEN:
\t\t\t\t// X-Men-only controls. No normal J2ME/emulator keypad.
\t\t\t\tArrays.fill(keyScales, 0.72f);

\t\t\t\t// L and R at the upper left/right.
\t\t\t\tsetSnap(KEY_SOFT_LEFT, SCREEN, RectSnap.INT_NORTHWEST, true);
\t\t\t\tsetSnap(KEY_SOFT_RIGHT, SCREEN, RectSnap.INT_NORTHEAST, true);

\t\t\t\t// Four-button D-pad, centered and completely inside the lower area.
\t\t\t\tsetSnap(KEY_DOWN, SCREEN, RectSnap.INT_SOUTH, true);
\t\t\t\tsetSnap(KEY_UP, KEY_DOWN, RectSnap.EXT_NORTH, true);
\t\t\t\tsetSnap(KEY_LEFT, KEY_UP, RectSnap.EXT_WEST, true);
\t\t\t\tsetSnap(KEY_RIGHT, KEY_UP, RectSnap.EXT_EAST, true);

\t\t\t\t// 5 and 0 are a compact pair in the lower-right, inside the screen.
\t\t\t\tsetSnap(KEY_NUM0, SCREEN, RectSnap.INT_SOUTHEAST, true);
\t\t\t\tsetSnap(KEY_NUM5, KEY_NUM0, RectSnap.EXT_NORTH, true);
\t\t\t\tbreak;
\t\t\tcase TYPE_NUM_ARR:
\t\t\tdefault:'''
block = block.replace('\\t', '\t')

# Replace the previous X-Men layout if one exists; otherwise insert it.
s = re.sub(r'\t\t\tcase TYPE_XMEN:.*?\t\t\tcase TYPE_NUM_ARR:', block, s, count=1, flags=re.S)
if 'case TYPE_XMEN:' not in s:
    needle = '\t\t\tcase TYPE_NUM_ARR:\n\t\t\tdefault:'
    if needle not in s:
        raise SystemExit('Could not find keyboard layout insertion point')
    s = s.replace(needle, block, 1)

# The control face uses a home-shaped up button. The game still receives KEY_UP.
s = s.replace(
    'keypad[KEY_UP] = new VirtualKey(Canvas.KEY_UP, ARROW_UP);',
    'keypad[KEY_UP] = new VirtualKey(Canvas.KEY_UP, "⌂");',
    1,
)
p.write_text(s)
PY

# X-Men-inspired steel/black/blue button palette.
python3 - <<'PY'
from pathlib import Path
p = Path('scripts/StandaloneLauncherActivity.java')
s = p.read_text()
s = s.replace('profile.vkBgColor = 0x4A7F82;', 'profile.vkBgColor = 0x252B33;')
s = s.replace('profile.vkBgColorSelected = 0x679EA1;', 'profile.vkBgColorSelected = 0x3B78A0;')
s = s.replace('profile.vkFgColor = 0x062C3F;', 'profile.vkFgColor = 0xDCE6ED;')
s = s.replace('profile.vkOutlineColor = 0x8CB9BC;', 'profile.vkOutlineColor = 0x70808E;')
p.write_text(s)
PY

bash scripts/build-standalone.sh
