#!/usr/bin/env bash
set -euo pipefail

# Build the standalone game, then replace the normal J2ME keyboard with a
# small X-Men-themed control set only.
python3 - <<'PY'
from pathlib import Path
import re

p = Path('scripts/build-standalone.sh')
s = p.read_text()

# The upstream keyboard already has all of the required key objects. Add one
# private layout type and make its layout explicit and deterministic.
s = s.replace(
    'private static final int TYPE_ARROWS = 6;',
    'private static final int TYPE_ARROWS = 6;\n\tprivate static final int TYPE_XMEN = 7;',
    1,
)

block = r'''\t\t\tcase TYPE_XMEN:
\t\t\t\t// X-Men standalone controls ONLY. Every other J2ME/emulator key is hidden.
\t\t\t\tArrays.fill(keyScales, 0.72f);
\n\t\t\t\t// L/R stay at the upper corners as requested.
\t\t\t\tsetSnap(KEY_SOFT_LEFT, SCREEN, RectSnap.INT_NORTHWEST, true);
\t\t\t\tsetSnap(KEY_SOFT_RIGHT, SCREEN, RectSnap.INT_NORTHEAST, true);
\n\t\t\t\t// Four-button D-pad: all four buttons are inside the screen and fully visible.
\t\t\t\t// Down is the bottom anchor, Up sits above it, Left/Right flank Up.
\t\t\t\tsetSnap(KEY_DOWN, SCREEN, RectSnap.INT_SOUTH, true);
\t\t\t\tsetSnap(KEY_UP, KEY_DOWN, RectSnap.EXT_NORTH, true);
\t\t\t\tsetSnap(KEY_LEFT, KEY_UP, RectSnap.EXT_WEST, true);
\t\t\t\tsetSnap(KEY_RIGHT, KEY_UP, RectSnap.EXT_EAST, true);
\n\t\t\t\t// 5 and 0 form a compact vertical pair in the lower-right, inset from the edge.
\t\t\t\tsetSnap(KEY_NUM0, SCREEN, RectSnap.INT_SOUTHEAST, true);
\t\t\t\tsetSnap(KEY_NUM5, KEY_NUM0, RectSnap.EXT_NORTH, true);
\n\t\t\t\t// Do not expose any other key.
\t\t\t\tsetSnap(KEY_NUM1, SCREEN, RectSnap.NO_SNAP, false);
\t\t\t\tsetSnap(KEY_NUM2, SCREEN, RectSnap.NO_SNAP, false);
\t\t\t\tsetSnap(KEY_NUM3, SCREEN, RectSnap.NO_SNAP, false);
\t\t\t\tsetSnap(KEY_NUM4, SCREEN, RectSnap.NO_SNAP, false);
\t\t\t\tsetSnap(KEY_NUM6, SCREEN, RectSnap.NO_SNAP, false);
\t\t\t\tsetSnap(KEY_NUM7, SCREEN, RectSnap.NO_SNAP, false);
\t\t\t\tsetSnap(KEY_NUM8, SCREEN, RectSnap.NO_SNAP, false);
\t\t\t\tsetSnap(KEY_NUM9, SCREEN, RectSnap.NO_SNAP, false);
\t\t\t\tsetSnap(KEY_STAR, SCREEN, RectSnap.NO_SNAP, false);
\t\t\t\tsetSnap(KEY_POUND, SCREEN, RectSnap.NO_SNAP, false);
\t\t\t\tsetSnap(KEY_D, SCREEN, RectSnap.NO_SNAP, false);
\t\t\t\tsetSnap(KEY_C, SCREEN, RectSnap.NO_SNAP, false);
\t\t\t\tsetSnap(KEY_UP_LEFT, SCREEN, RectSnap.NO_SNAP, false);
\t\t\t\tsetSnap(KEY_UP_RIGHT, SCREEN, RectSnap.NO_SNAP, false);
\t\t\t\tsetSnap(KEY_DOWN_LEFT, SCREEN, RectSnap.NO_SNAP, false);
\t\t\t\tsetSnap(KEY_DOWN_RIGHT, SCREEN, RectSnap.NO_SNAP, false);
\t\t\t\tsetSnap(KEY_FIRE, SCREEN, RectSnap.NO_SNAP, false);
\t\t\t\tsetSnap(KEY_A, SCREEN, RectSnap.NO_SNAP, false);
\t\t\t\tsetSnap(KEY_B, SCREEN, RectSnap.NO_SNAP, false);
\t\t\t\tsetSnap(KEY_MENU, SCREEN, RectSnap.NO_SNAP, false);
\t\t\t\tbreak;
\t\t\tcase TYPE_NUM_ARR:
\t\t\tdefault:'''

# Replace any previous X-Men block, otherwise inject a fresh one before the
# standard numeric layout.
s = re.sub(r'\t\t\tcase TYPE_XMEN:.*?\t\t\tcase TYPE_NUM_ARR:', block, s, count=1, flags=re.S)
if 'case TYPE_XMEN:' not in s:
    needle = '\t\t\tcase TYPE_NUM_ARR:\n\t\t\tdefault:'
    if needle not in s:
        raise SystemExit('Could not find keyboard layout insertion point')
    s = s.replace(needle, block, 1)

# Labels used by the supplied control concept.
s = s.replace(
    'keypad[KEY_UP] = new VirtualKey(Canvas.KEY_UP, ARROW_UP);',
    'keypad[KEY_UP] = new VirtualKey(Canvas.KEY_UP, "⌂");',
    1,
)
s = s.replace(
    'keypad[KEY_FIRE] = new VirtualKey(Canvas.KEY_FIRE, "F");',
    'keypad[KEY_FIRE] = new VirtualKey(Canvas.KEY_FIRE, "Ⅱ");',
    1,
)
p.write_text(s)
PY

# Use a restrained steel/black/blue X-Men-style palette instead of the generic
# cyan emulator controls. The selected state remains bright for feedback.
python3 - <<'PY'
from pathlib import Path
p = Path('scripts/StandaloneLauncherActivity.java')
s = p.read_text()
s = s.replace('profile.vkBgColor = 0x4A7F82;', 'profile.vkBgColor = 0x252B33;')
s = s.replace('profile.vkBgColorSelected = 0x679EA1;', 'profile.vkBgColorSelected = 0x3B78A0;')
s = s.replace('profile.vkFgColor = 0x062C3F;', 'profile.vkFgColor = 0xDCE6ED;')
s = s.replace('profile.vkFgColorSelected = 0xFFFFFF;', 'profile.vkFgColorSelected = 0xFFFFFF;')
s = s.replace('profile.vkOutlineColor = 0x8CB9BC;', 'profile.vkOutlineColor = 0x70808E;')
p.write_text(s)
PY

bash scripts/build-standalone.sh
