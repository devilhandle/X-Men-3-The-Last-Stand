#!/usr/bin/env bash
set -euo pipefail

# Build the working standalone APK first, then replace only the X-Men
# keyboard layout and renderer. No standard J2ME keypad is enabled.
bash scripts/build-standalone.sh

python3 - <<'PY'
from pathlib import Path
import re

p = Path('runtime/app/src/main/java/javax/microedition/lcdui/keyboard/VirtualKeyboard.java')
s = p.read_text()

start = s.find('\t\t\tcase TYPE_XMEN:')
end = s.find('\t\t\tcase TYPE_NUM_ARR:', start)
if start < 0 or end < 0:
    raise SystemExit('TYPE_XMEN block not found')

case = '''\t\t\tcase TYPE_XMEN:\n\t\t\t\t// X-Men 3 custom touch layout: L/R at the top of the\n\t\t\t\t// control area, a four-way D-pad on the left, and 5/0\n\t\t\t\t// stacked on the right. Every other virtual key is hidden.\n\t\t\t\tArrays.fill(keyScales, 0.72f);\n\t\t\t\tfor (VirtualKey key : keypad) {\n\t\t\t\t\tkey.visible = false;\n\t\t\t\t}\n\t\t\t\tkeypad[KEY_SOFT_LEFT].visible = true;\n\t\t\t\tkeypad[KEY_SOFT_RIGHT].visible = true;\n\t\t\t\tkeypad[KEY_UP].visible = true;\n\t\t\t\tkeypad[KEY_LEFT].visible = true;\n\t\t\t\tkeypad[KEY_RIGHT].visible = true;\n\t\t\t\tkeypad[KEY_DOWN].visible = true;\n\t\t\t\tkeypad[KEY_NUM5].visible = true;\n\t\t\t\tkeypad[KEY_NUM0].visible = true;\n\t\t\t\tbreak;\n'''
s = s[:start] + case + s[end:]

marker = '''\t\t\tsnapKeys();\n\t\t\toverlayView.postInvalidate();'''
replacement = '''\t\t\tsnapKeys();\n\t\t\tif (layoutVariant == TYPE_XMEN) {\n\t\t\t\tlayoutXmenControls();\n\t\t\t}\n\t\t\toverlayView.postInvalidate();'''
if marker not in s:
    raise SystemExit('resize marker not found')
s = s.replace(marker, replacement, 1)

layout_method = '''\n\tprivate void layoutXmenControls() {\n\t\tfloat w = screen.width();\n\t\tfloat h = screen.height();\n\t\tfloat top = virtualScreen.bottom;\n\t\tif (top <= 0 || top >= h - 80) {\n\t\t\ttop = h * 0.62f;\n\t\t}\n\t\tfloat area = Math.max(180f, h - top);\n\t\tfloat size = keypad[KEY_UP].rect.width();\n\t\tfloat half = size * 0.5f;\n\n\t\t// L / R: centered near the top of the touch-control panel.\n\t\tplaceXmen(KEY_SOFT_LEFT, w * 0.40f - half, top + area * 0.14f - half);\n\t\tplaceXmen(KEY_SOFT_RIGHT, w * 0.60f - half, top + area * 0.14f - half);\n\n\t\t// Four-way D-pad on the left.\n\t\tfloat cx = w * 0.30f;\n\t\tfloat cy = top + area * 0.66f;\n\t\tfloat gap = size * 0.88f;\n\t\tplaceXmen(KEY_UP, cx - half, cy - gap - half);\n\t\tplaceXmen(KEY_LEFT, cx - gap - half, cy - half);\n\t\tplaceXmen(KEY_RIGHT, cx + gap - half, cy - half);\n\t\tplaceXmen(KEY_DOWN, cx - half, cy + gap - half);\n\n\t\t// 5 / 0 vertical pair on the right.\n\t\tfloat rx = w * 0.78f;\n\t\tplaceXmen(KEY_NUM5, rx - half, cy - gap * 0.55f - half);\n\t\tplaceXmen(KEY_NUM0, rx - half, cy + gap * 0.55f - half);\n\t}\n\n\tprivate void placeXmen(int key, float left, float top) {\n\t\tVirtualKey vKey = keypad[key];\n\t\tfloat width = vKey.rect.width();\n\t\tfloat height = vKey.rect.height();\n\t\tvKey.rect.set(left, top, left + width, top + height);\n\t\tvKey.snapValid = true;\n\t}\n'''
paint_marker = '\t\tvoid paint(CanvasWrapper g) {'
idx = s.find(paint_marker)
if idx < 0:
    raise SystemExit('VirtualKey paint method not found')
s = s[:idx] + layout_method + '\n' + s[idx:]

pattern = re.compile(r'\t\tvoid paint\(CanvasWrapper g\) \{.*?\n\t\t\}\n\n\t\t@NonNull', re.S)
match = pattern.search(s)
if not match:
    raise SystemExit('paint method pattern not found')

paint = '''\t\tvoid paint(CanvasWrapper g) {\n\t\t\tint alpha = (opaque || layoutEditMode != LAYOUT_EOF ? 0xFF : settings.vkAlpha) << 24;\n\t\t\tint bg = selected ? 0x6EABB0 : 0x4A858B;\n\t\t\tint dark = 0x081F2A;\n\t\t\tint ring = 0x12343F;\n\t\t\tint highlight = 0x9ACFD2;\n\n\t\t\t// Soft drop shadow.\n\t\t\tRectF shadow = new RectF(rect);\n\t\t\tshadow.offset(0, rect.height() * 0.09f);\n\t\t\tg.setFillColor((0x33 << 24));\n\t\t\tg.fillArc(shadow, 0, 360);\n\n\t\t\t// Dark outer rim.\n\t\t\tg.setFillColor(alpha | dark);\n\t\t\tg.fillArc(rect, 0, 360);\n\n\t\t\t// Main blue/teal face.\n\t\t\tfloat inset = rect.width() * 0.055f;\n\t\t\tRectF face = new RectF(rect.left + inset, rect.top + inset,\n\t\t\t\t\trect.right - inset, rect.bottom - inset);\n\t\t\tg.setFillColor(alpha | bg);\n\t\t\tg.fillArc(face, 0, 360);\n\n\t\t\t// Inner rim and top highlight for the glossy 3D look.\n\t\t\tfloat inset2 = rect.width() * 0.13f;\n\t\t\tRectF innerRect = new RectF(rect.left + inset2, rect.top + inset2,\n\t\t\t\t\trect.right - inset2, rect.bottom - inset2);\n\t\t\tg.setDrawColor(alpha | ring);\n\t\t\tg.drawArc(innerRect, 0, 360);\n\n\t\t\tRectF shine = new RectF(face.left + face.width() * 0.18f,\n\t\t\t\t\tface.top + face.height() * 0.12f,\n\t\t\t\t\tface.right - face.width() * 0.18f,\n\t\t\t\t\tface.top + face.height() * 0.34f);\n\t\t\tg.setFillColor(alpha | highlight);\n\t\t\tg.fillArc(shine, 180, 180);\n\n\t\t\t// Strong center icon/label.\n\t\t\tg.setTextColor(alpha | (selected ? 0xFFFFFF : 0x063447));\n\t\t\tg.setTextScale(1.0f);\n\t\t\tg.drawString(label, rect.centerX(), rect.centerY());\n\t\t}\n\n\t\t@NonNull'''
s = s[:match.start()] + paint + s[match.end():]
p.write_text(s)
PY

cd runtime
./gradlew :app:assembleStandaloneDebug --no-daemon --stacktrace
