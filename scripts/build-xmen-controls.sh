#!/usr/bin/env bash
set -euo pipefail

# Build the standalone X-Men APK and use the supplied PNG as the visual keypad.
bash scripts/build-standalone.sh

mkdir -p runtime/app/src/main/assets
cp IMG_20260901_020905_484.png runtime/app/src/main/assets/xmen_buttons.png

python3 - <<'PY'
from pathlib import Path
import re

p = Path('runtime/app/src/main/java/javax/microedition/lcdui/graphics/CanvasWrapper.java')
s = p.read_text()
if 'drawAssetBitmap' not in s:
    s = s.replace('import android.graphics.Bitmap;\n', 'import android.graphics.Bitmap;\nimport android.graphics.BitmapFactory;\nimport java.io.InputStream;\n', 1)
    s = s.replace('\tprivate final Paint imgPaint = new Paint();\n', '\tprivate final Paint imgPaint = new Paint();\n\tprivate Bitmap assetBitmap;\n', 1)
    marker = '\tpublic void drawImage(Image image, RectF dst) {\n'
    method = '''\tpublic void drawAssetBitmap(String assetName, RectF dst) {\n\t\ttry {\n\t\t\tif (assetBitmap == null) {\n\t\t\t\ttry (InputStream in = ContextHolder.getAppContext().getAssets().open(assetName)) {\n\t\t\t\t\tassetBitmap = BitmapFactory.decodeStream(in);\n\t\t\t\t}\n\t\t\t}\n\t\t\tif (assetBitmap != null) {\n\t\t\t\tassetBitmap.prepareToDraw();\n\t\t\t\tcanvas.drawBitmap(assetBitmap, null, dst, imgPaint);\n\t\t\t}\n\t\t} catch (Exception ignored) {\n\t\t}\n\t}\n\n'''
    if marker not in s:
        raise SystemExit('CanvasWrapper drawImage marker not found')
    s = s.replace(marker, method + marker, 1)
    p.write_text(s)

p = Path('runtime/app/src/main/java/javax/microedition/lcdui/keyboard/VirtualKeyboard.java')
s = p.read_text()

# Replace the normal paint method with the supplied PNG for the X-Men layout.
pattern = re.compile(r'\t@Override\n\tpublic void paint\(CanvasWrapper g\) \{.*?\n\t\}\n\n\t@Override\n\tpublic boolean pointerPressed', re.S)
match = pattern.search(s)
if not match:
    raise SystemExit('VirtualKeyboard paint method not found')
paint = '''\t@Override\n\tpublic void paint(CanvasWrapper g) {\n\t\tif (!visible) return;\n\t\tif (layoutVariant == TYPE_XMEN) {\n\t\t\tfloat overlayHeight = screen.height() * 0.38f;\n\t\t\tRectF dst = new RectF(screen.left, screen.bottom - overlayHeight,\n\t\t\t\t\tscreen.right, screen.bottom);\n\t\t\tg.drawAssetBitmap("xmen_buttons.png", dst);\n\t\t\treturn;\n\t\t}\n\t\tfor (VirtualKey key : keypad) {\n\t\t\tif (key.visible) key.paint(g);\n\t\t}\n\t}\n\n\tprivate VirtualKey xmenKeyAt(float x, float y) {\n\t\tif (screen == null) return null;\n\t\tfloat overlayHeight = screen.height() * 0.38f;\n\t\tfloat top = screen.bottom - overlayHeight;\n\t\tif (y < top || y > screen.bottom) return null;\n\n\t\tfloat relX = (x - screen.left) / screen.width();\n\t\tfloat relY = (y - top) / overlayHeight;\n\n\t\t// These positions are taken from the supplied 564x478 PNG.\n\t\tfloat[][] zones = {\n\t\t\t\t{0.43085f, 0.16736f}, // L\n\t\t\t\t{0.60106f, 0.16736f}, // R\n\t\t\t\t{0.30674f, 0.48117f}, // Up\n\t\t\t\t{0.18617f, 0.64435f}, // Left\n\t\t\t\t{0.42908f, 0.64435f}, // Right\n\t\t\t\t{0.30674f, 0.82427f}, // Down\n\t\t\t\t{0.75887f, 0.53975f}, // 5\n\t\t\t\t{0.82092f, 0.74895f}  // 0\n\t\t};\n\t\tint[] keys = {KEY_SOFT_LEFT, KEY_SOFT_RIGHT, KEY_UP, KEY_LEFT,\n\t\t\t\tKEY_RIGHT, KEY_DOWN, KEY_NUM5, KEY_NUM0};\n\t\tfloat[] radii = {0.057f, 0.057f, 0.075f, 0.075f,\n\t\t\t\t0.075f, 0.075f, 0.070f, 0.070f};\n\t\tfor (int i = 0; i < zones.length; i++) {\n\t\t\tfloat dx = relX - zones[i][0];\n\t\t\tfloat dy = relY - zones[i][1];\n\t\t\tif (dx * dx + dy * dy <= radii[i] * radii[i]) return keypad[keys[i]];\n\t\t}\n\t\treturn null;\n\t}\n\n\t@Override\n\tpublic boolean pointerPressed'''
s = s[:match.start()] + paint + s[match.end():]

# Make the PNG button artwork itself the touch map.
s = s.replace('''\tpublic boolean pointerPressed(int pointer, float x, float y) {\n\t\tswitch (layoutEditMode) {''', '''\tpublic boolean pointerPressed(int pointer, float x, float y) {\n\t\tif (layoutVariant == TYPE_XMEN && layoutEditMode == LAYOUT_EOF) {\n\t\t\tif (pointer < 0 || pointer >= associatedKeys.length) return false;\n\t\t\tVirtualKey key = xmenKeyAt(x, y);\n\t\t\tif (key != null) {\n\t\t\t\tvibrate();\n\t\t\t\tassociatedKeys[pointer] = key;\n\t\t\t\tkey.onDown();\n\t\t\t\toverlayView.postInvalidate();\n\t\t\t\treturn true;\n\t\t\t}\n\t\t\treturn false;\n\t\t}\n\t\tswitch (layoutEditMode) {''', 1)

s = s.replace('''\tpublic boolean pointerDragged(int pointer, float x, float y) {\n\t\tswitch (layoutEditMode) {''', '''\tpublic boolean pointerDragged(int pointer, float x, float y) {\n\t\tif (layoutVariant == TYPE_XMEN && layoutEditMode == LAYOUT_EOF) {\n\t\t\tif (pointer < 0 || pointer >= associatedKeys.length) return false;\n\t\t\tVirtualKey current = associatedKeys[pointer];\n\t\t\tVirtualKey next = xmenKeyAt(x, y);\n\t\t\tif (current != next) {\n\t\t\t\tif (current != null) current.onUp();\n\t\t\t\tassociatedKeys[pointer] = next;\n\t\t\t\tif (next != null) {\n\t\t\t\t\tvibrate();\n\t\t\t\t\tnext.onDown();\n\t\t\t\t}\n\t\t\t\toverlayView.postInvalidate();\n\t\t\t}\n\t\t\treturn true;\n\t\t}\n\t\tswitch (layoutEditMode) {''', 1)

s = s.replace('''\tpublic boolean pointerReleased(int pointer, float x, float y) {\n\t\tif (layoutEditMode == LAYOUT_EOF) {\n\t\t\tif (pointer >= associatedKeys.length) {''', '''\tpublic boolean pointerReleased(int pointer, float x, float y) {\n\t\tif (layoutVariant == TYPE_XMEN && layoutEditMode == LAYOUT_EOF) {\n\t\t\tif (pointer < 0 || pointer >= associatedKeys.length) return false;\n\t\t\tVirtualKey key = associatedKeys[pointer];\n\t\t\tif (key != null) {\n\t\t\t\tassociatedKeys[pointer] = null;\n\t\t\t\tkey.onUp();\n\t\t\t\toverlayView.postInvalidate();\n\t\t\t}\n\t\t\treturn true;\n\t\t}\n\t\tif (layoutEditMode == LAYOUT_EOF) {\n\t\t\tif (pointer >= associatedKeys.length) {''', 1)

p.write_text(s)
PY

cd runtime
./gradlew :app:assembleStandaloneDebug --no-daemon --stacktrace
