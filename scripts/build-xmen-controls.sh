#!/usr/bin/env bash
set -euo pipefail

# build-standalone.sh already installs the X-Men-specific key layout and
# positioning. This script only replaces the button renderer, then builds.
bash scripts/build-standalone.sh

python3 - <<'PY'
from pathlib import Path
import re

p = Path('runtime/app/src/main/java/javax/microedition/lcdui/keyboard/VirtualKeyboard.java')
s = p.read_text()

pattern = re.compile(
    r'\t\tvoid paint\(CanvasWrapper g\) \{.*?\n\t\t\}\n\n\t\t@NonNull',
    re.S,
)
match = pattern.search(s)
if not match:
    raise SystemExit('VirtualKey paint method not found')

paint = '''\t\tvoid paint(CanvasWrapper g) {
\t\t\tint alpha = (opaque || layoutEditMode != LAYOUT_EOF ? 0xFF : settings.vkAlpha) << 24;
\t\t\tint faceColor = selected ? 0x78AEB2 : 0x3F7E87;
\t\t\tint edgeColor = 0x061A22;
\t\t\tint rimColor = 0x1B3E48;
\t\t\tint highlightColor = 0x79B7BB;
\t\t\tint textColor = selected ? 0xFFFFFF : 0x063447;

\t\t\t// Drop shadow.
\t\t\tRectF shadow = new RectF(rect);
\t\t\tshadow.offset(0, Math.max(2.0f, rect.height() * 0.08f));
\t\t\tg.setFillColor(0x44000000);
\t\t\tg.fillArc(shadow, 0, 360);

\t\t\t// Dark outer bezel.
\t\t\tg.setFillColor(alpha | edgeColor);
\t\t\tg.fillArc(rect, 0, 360);

\t\t\t// Main glossy face.
\t\t\tfloat inset = rect.width() * 0.06f;
\t\t\tRectF face = new RectF(rect.left + inset, rect.top + inset,
\t\t\t\t\trect.right - inset, rect.bottom - inset);
\t\t\tg.setFillColor(alpha | faceColor);
\t\t\tg.fillArc(face, 0, 360);

\t\t\t// Inner dark rim.
\t\t\tfloat rim = rect.width() * 0.11f;
\t\t\tRectF inner = new RectF(rect.left + rim, rect.top + rim,
\t\t\t\t\trect.right - rim, rect.bottom - rim);
\t\t\tg.setDrawColor(alpha | rimColor);
\t\t\tg.drawArc(inner, 0, 360);

\t\t\t// Upper shine.
\t\t\tRectF shine = new RectF(face.left + face.width() * 0.20f,
\t\t\t\t\tface.top + face.height() * 0.12f,
\t\t\t\t\tface.right - face.width() * 0.20f,
\t\t\t\t\tface.top + face.height() * 0.32f);
\t\t\tg.setFillColor(alpha | highlightColor);
\t\t\tg.fillArc(shine, 180, 180);

\t\t\t// Center label/icon.
\t\t\tg.setTextColor(alpha | textColor);
\t\t\tg.drawString(label, rect.centerX(), rect.centerY());
\t\t}

\t\t@NonNull'''

s = s[:match.start()] + paint + s[match.end():]
p.write_text(s)
PY

cd runtime
./gradlew :app:assembleStandaloneDebug --no-daemon --stacktrace
