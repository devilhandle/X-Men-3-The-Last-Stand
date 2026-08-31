#!/usr/bin/env bash
set -euo pipefail

# Build the working standalone APK first, then replace only the X-Men
# keyboard layout. No standard J2ME keypad is enabled.
bash scripts/build-standalone.sh

python3 - <<'PY'
from pathlib import Path

p = Path('runtime/app/src/main/java/javax/microedition/lcdui/keyboard/VirtualKeyboard.java')
s = p.read_text()

start = s.find('\t\t\tcase TYPE_XMEN:')
end = s.find('\t\t\tcase TYPE_NUM_ARR:', start)
if start < 0 or end < 0:
    raise SystemExit('TYPE_XMEN block not found')

case = '''\t\t\tcase TYPE_XMEN:\n\t\t\t\t// X-Men 3 controls only: L, R, arrows, 5 and 0.\n\t\t\t\t// Every other virtual key is explicitly hidden.\n\t\t\t\tArrays.fill(keyScales, 0.82f);\n\t\t\t\tfor (VirtualKey key : keypad) {\n\t\t\t\t\tkey.visible = false;\n\t\t\t\t}\n\n\t\t\t\tfinal float m = keySize * 0.85f;\n\n\t\t\t\t// L / R: upper left/right, inset from the edges.\n\t\t\t\tsetSnap(KEY_SOFT_LEFT, SCREEN, RectSnap.INT_NORTHWEST, true);\n\t\t\t\tkeypad[KEY_SOFT_LEFT].snapOffset.set(m, m);\n\t\t\t\tsetSnap(KEY_SOFT_RIGHT, SCREEN, RectSnap.INT_NORTHEAST, true);\n\t\t\t\tkeypad[KEY_SOFT_RIGHT].snapOffset.set(-m, m);\n\n\t\t\t\t// Four-way D-pad: lower-left, inset from both edges.\n\t\t\t\tsetSnap(KEY_DOWN, SCREEN, RectSnap.INT_SOUTHWEST, true);\n\t\t\t\tkeypad[KEY_DOWN].snapOffset.set(m * 1.35f, -m * 0.80f);\n\t\t\t\tsetSnap(KEY_LEFT, KEY_DOWN, RectSnap.EXT_WEST, true);\n\t\t\t\tsetSnap(KEY_RIGHT, KEY_DOWN, RectSnap.EXT_EAST, true);\n\t\t\t\tsetSnap(KEY_UP, KEY_DOWN, RectSnap.EXT_NORTH, true);\n\n\t\t\t\t// 5 / 0: lower-right, vertical pair, inset from the edges.\n\t\t\t\tsetSnap(KEY_NUM0, SCREEN, RectSnap.INT_SOUTHEAST, true);\n\t\t\t\tkeypad[KEY_NUM0].snapOffset.set(-m, -m * 0.80f);\n\t\t\t\tsetSnap(KEY_NUM5, KEY_NUM0, RectSnap.EXT_NORTH, true);\n\t\t\t\tbreak;\n'''

s = s[:start] + case + s[end:]
p.write_text(s)
PY

cd runtime
./gradlew :app:assembleStandaloneDebug --no-daemon --stacktrace
