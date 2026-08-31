#!/usr/bin/env bash
set -euo pipefail

python3 - <<'PY'
from pathlib import Path
import re

p = Path('scripts/build-standalone.sh')
s = p.read_text()
tab = chr(9)
nl = chr(10)

old = 'private static final int TYPE_ARROWS = 6;'
new = old + nl + tab + 'private static final int TYPE_XMEN = 7;'
s = s.replace(old, new, 1)

block = (
    tab + tab + tab + 'case TYPE_XMEN:' + nl
    + tab + tab + tab + tab + '// X-Men-only controls. No normal J2ME/emulator keypad.' + nl
    + tab + tab + tab + tab + 'Arrays.fill(keyScales, 0.72f);' + nl + nl
    + tab + tab + tab + tab + '// L and R at the upper left/right.' + nl
    + tab + tab + tab + tab + 'setSnap(KEY_SOFT_LEFT, SCREEN, RectSnap.INT_NORTHWEST, true);' + nl
    + tab + tab + tab + tab + 'setSnap(KEY_SOFT_RIGHT, SCREEN, RectSnap.INT_NORTHEAST, true);' + nl + nl
    + tab + tab + tab + tab + '// Hidden bottom anchor keeps the D-pad comfortably inside the screen.' + nl
    + tab + tab + tab + tab + 'setSnap(KEY_FIRE, SCREEN, RectSnap.INT_SOUTH, false);' + nl
    + tab + tab + tab + tab + 'setSnap(KEY_DOWN, KEY_FIRE, RectSnap.EXT_NORTH, true);' + nl
    + tab + tab + tab + tab + 'setSnap(KEY_UP, KEY_DOWN, RectSnap.EXT_NORTH, true);' + nl
    + tab + tab + tab + tab + 'setSnap(KEY_LEFT, KEY_UP, RectSnap.EXT_WEST, true);' + nl
    + tab + tab + tab + tab + 'setSnap(KEY_RIGHT, KEY_UP, RectSnap.EXT_EAST, true);' + nl + nl
    + tab + tab + tab + tab + '// Hidden lower-right anchor keeps 5/0 away from the screen edge.' + nl
    + tab + tab + tab + tab + 'setSnap(KEY_MENU, SCREEN, RectSnap.INT_SOUTHEAST, false);' + nl
    + tab + tab + tab + tab + 'setSnap(KEY_NUM0, KEY_MENU, RectSnap.EXT_NORTHWEST, true);' + nl
    + tab + tab + tab + tab + 'setSnap(KEY_NUM5, KEY_NUM0, RectSnap.EXT_NORTH, true);' + nl
    + tab + tab + tab + tab + 'break;' + nl
    + tab + tab + tab + 'case TYPE_NUM_ARR:' + nl
    + tab + tab + tab + 'default:'
)

# Replace any previous X-Men block, or insert it before the normal numeric layout.
s = re.sub(tab + tab + tab + r'case TYPE_XMEN:.*?' + tab + tab + tab + r'case TYPE_NUM_ARR:', block, s, count=1, flags=re.S)
if 'case TYPE_XMEN:' not in s:
    needle = tab + tab + tab + 'case TYPE_NUM_ARR:' + nl + tab + tab + tab + 'default:'
    if needle not in s:
        raise SystemExit('Could not find keyboard layout insertion point')
    s = s.replace(needle, block, 1)

s = s.replace(
    'keypad[KEY_UP] = new VirtualKey(Canvas.KEY_UP, ARROW_UP);',
    'keypad[KEY_UP] = new VirtualKey(Canvas.KEY_UP, "⌂");',
    1,
)
p.write_text(s)
PY

# Steel / black / blue palette inspired by the game's metallic X-Men look.
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
