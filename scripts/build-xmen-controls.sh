#!/usr/bin/env bash
set -euo pipefail

# Build the standalone X-Men APK and use the supplied PNG as the visual
# keypad overlay at the bottom of the game. Touch zones are mapped directly
# to the buttons visible in that PNG.
bash scripts/build-standalone.sh

mkdir -p runtime/app/src/main/assets
cp IMG_20260901_020905_484.png runtime/app/src/main/assets/xmen_buttons.png

python3 - <<'PY'
from pathlib import Path

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

# The PNG itself is visual only. Do not use the normal VirtualKey rectangles
# for the X-Men layout because those rectangles do not match the artwork.
# Instead, convert the physical touch point into the PNG's 564x478 coordinate
# space and test against the exact visible button centers.
old = '''\t@Override\n\tpublic void paint(CanvasWrapper g) {\n\t\tif (!visible) return;\n\t\t// The supplied artwork is the complete X-Men button panel.\n\t\tif (layoutVariant == TYPE_XMEN) {\n\t\t\tfloat overlayHeight = screen.height() * 0.38f;\n\t\t\tRectF dst = new RectF(screen.left, screen.bottom - overlayHeight,\n\t\t\t\t\tscreen.right, screen.bottom);\n\t\t\tg.drawAssetBitmap("xmen_buttons.png", dst);\n\t\t\treturn;\n\t\t}\n\t\tfor (VirtualKey key : keypad) {\n\t\t\tif (key.visible) key.paint(g);\n\t\t}\n\t}\n\n\tprivate VirtualKey xmenKeyAt(float x, float y) {\n\t\tif (screen == null) return null;\n\t\tfloat overlayHeight = screen.height() * 0.38f;\n\t\tfloat top = screen.bottom - overlayHeight;\n\t\tif (y < top || y > screen.bottom) return null;\n\n\t\tfloat w = screen.width();\n\t\tfloat relX = (x - screen.left) / w;\n\t\tfloat relY = (y - top) / overlayHeight;\n\n\t\t// These centers match the supplied X-Men artwork. Each hit area is\n\t\t// deliberately a little larger than the visible button for touch use.\n\t\tfloat radius = 0.065f;\n\t\tfloat[][] zones = {\n\t\t\t\t{0.390f, 0.127f}, // L\n\t\t\t\t{0.540f, 0.127f}, // R\n\t\t\t\t{0.310f, 0.372f}, // Up / home symbol\n\t\t\t\t{0.188f, 0.511f}, // Left\n\t\t\t\t{0.432f, 0.511f}, // Right\n\t\t\t\t{0.310f, 0.647f}, // Down\n\t\t\t\t{0.729f, 0.431f}, // 5\n\t\t\t\t{0.763f, 0.567f}  // 0\n\t\t};\n\t\tint[] keys = {KEY_SOFT_LEFT, KEY_SOFT_RIGHT, KEY_UP, KEY_LEFT,\n\t\t\t\tKEY_RIGHT, KEY_DOWN, KEY_NUM5, KEY_NUM0};\n\t\tfor (int i = 0; i < zones.length; i++) {\n\t\t\tfloat dx = relX - zones[i][0];\n\t\t\tfloat dy = relY - zones[i][1];\n\t\t\tif (dx * dx + dy * dy <= radius * radius) return keypad[keys[i]];\n\t\t}\n\t\treturn null;\n\t}\n'''
new = '''\t@Override\n\tpublic void paint(CanvasWrapper g) {\n\t\tif (!visible) return;\n\t\tif (layoutVariant == TYPE_XMEN) {\n\t\t\tfloat overlayHeight = screen.height() * 0.38f;\n\t\t\tRectF dst = new RectF(screen.left, screen.bottom - overlayHeight,\n\t\t\t\t\tscreen.right, screen.bottom);\n\t\t\tg.drawAssetBitmap("xmen_buttons.png", dst);\n\t\t\treturn;\n\t\t}\n\t\tfor (VirtualKey key : keypad) {\n\t\t\tif (key.visible) key.paint(g);\n\t\t}\n\t}\n\n\tprivate VirtualKey xmenKeyAt(float x, float y) {\n\t\tif (screen == null) return null;\n\n\t\t// The supplied PNG is 564x478. It is stretched into the same rectangle\n\t\t// used for drawing, so touch coordinates are converted back into PNG\n\t\t// coordinates before hit testing.\n\t\tfinal float imageWidth = 564f;\n\t\tfinal float imageHeight = 478f;\n\t\tfloat overlayHeight = screen.height() * 0.38f;\n\t\tfloat top = screen.bottom - overlayHeight;\n\t\tif (x < screen.left || x > screen.right || y < top || y > screen.bottom) return null;\n\n\t\tfloat px = (x - screen.left) * imageWidth / screen.width();\n\t\tfloat py = (y - top) * imageHeight / overlayHeight;\n\n\t\t// Centers are taken from the actual supplied PNG artwork.\n\t\t// Internal keypad indices are used here (not Canvas key-code values).\n\t\tfinal float[][] zones = {\n\t\t\t\t{243f, 80f},   // L  -> KEY_SOFT_LEFT (12)\n\t\t\t\t{339f, 80f},   // R  -> KEY_SOFT_RIGHT (13)\n\t\t\t\t{173f, 230f},  // up -> KEY_UP (17)\n\t\t\t\t{105f, 308f},  // left -> KEY_LEFT (19)\n\t\t\t\t{242f, 308f},  // right -> KEY_RIGHT (20)\n\t\t\t\t{173f, 394f},  // down -> KEY_DOWN (22)\n\t\t\t\t{428f, 258f},  // 5 -> KEY_NUM5 (4)\n\t\t\t\t{463f, 358f}   // 0 -> KEY_NUM0 (9)\n\t\t};\n\t\tfinal int[] keys = {12, 13, 17, 19, 20, 22, 4, 9};\n\t\tfinal float[] radii = {32f, 32f, 43f, 43f, 43f, 43f, 40f, 40f};\n\n\t\tfor (int i = 0; i < zones.length; i++) {\n\t\t\tfloat dx = px - zones[i][0];\n\t\t\tfloat dy = py - zones[i][1];\n\t\t\tif (dx * dx + dy * dy <= radii[i] * radii[i]) {\n\t\t\t\treturn keypad[keys[i]];\n\t\t\t}\n\t\t}\n\t\treturn null;\n\t}\n'''
if old not in s:
    raise SystemExit('old X-Men paint/hit-test block not found')
s = s.replace(old, new, 1)

# Replace the X-Men-specific pointer handling with strict per-finger handling.
old = '''\t@Override\n\tpublic boolean pointerPressed(int pointer, float x, float y) {\n\t\tif (layoutVariant == TYPE_XMEN && layoutEditMode == LAYOUT_EOF) {\n\t\t\tif (pointer < 0 || pointer >= associatedKeys.length) return false;\n\t\t\tVirtualKey key = xmenKeyAt(x, y);\n\t\t\tif (key != null) {\n\t\t\t\tvibrate();\n\t\t\t\tassociatedKeys[pointer] = key;\n\t\t\t\tkey.onDown();\n\t\t\t\toverlayView.postInvalidate();\n\t\t\t\treturn true;\n\t\t\t}\n\t\t\treturn false;\n\t\t}\n\t\tswitch (layoutEditMode) {'''
new = '''\t@Override\n\tpublic boolean pointerPressed(int pointer, float x, float y) {\n\t\tif (layoutVariant == TYPE_XMEN && layoutEditMode == LAYOUT_EOF) {\n\t\t\tif (pointer < 0 || pointer >= associatedKeys.length) return false;\n\t\t\tVirtualKey key = xmenKeyAt(x, y);\n\t\t\tif (key == null) return false;\n\t\t\tVirtualKey oldKey = associatedKeys[pointer];\n\t\t\tif (oldKey != null && oldKey != key) oldKey.onUp();\n\t\t\tassociatedKeys[pointer] = key;\n\t\t\tvibrate();\n\t\t\tkey.onDown();\n\t\t\toverlayView.postInvalidate();\n\t\t\treturn true;\n\t\t}\n\t\tswitch (layoutEditMode) {'''
if old not in s:
    raise SystemExit('old X-Men pointerPressed block not found')
s = s.replace(old, new, 1)

old = '''\t@Override\n\tpublic boolean pointerDragged(int pointer, float x, float y) {\n\t\tif (layoutVariant == TYPE_XMEN && layoutEditMode == LAYOUT_EOF) {\n\t\t\tif (pointer < 0 || pointer >= associatedKeys.length) return false;\n\t\t\tVirtualKey current = associatedKeys[pointer];\n\t\t\tVirtualKey next = xmenKeyAt(x, y);\n\t\t\tif (current != next) {\n\t\t\t\tif (current != null) current.onUp();\n\t\t\t\tassociatedKeys[pointer] = next;\n\t\t\t\tif (next != null) {\n\t\t\t\t\tvibrate();\n\t\t\t\t\tnext.onDown();\n\t\t\t\t}\n\t\t\t\toverlayView.postInvalidate();\n\t\t\t}\n\t\t\treturn true;\n\t\t}\n\t\tswitch (layoutEditMode) {'''
new = '''\t@Override\n\tpublic boolean pointerDragged(int pointer, float x, float y) {\n\t\tif (layoutVariant == TYPE_XMEN && layoutEditMode == LAYOUT_EOF) {\n\t\t\tif (pointer < 0 || pointer >= associatedKeys.length) return false;\n\t\t\tVirtualKey current = associatedKeys[pointer];\n\t\t\tVirtualKey next = xmenKeyAt(x, y);\n\t\t\tif (current != next) {\n\t\t\t\tif (current != null) current.onUp();\n\t\t\t\tassociatedKeys[pointer] = next;\n\t\t\t\tif (next != null) {\n\t\t\t\t\tvibrate();\n\t\t\t\t\tnext.onDown();\n\t\t\t\t}\n\t\t\t\toverlayView.postInvalidate();\n\t\t\t}\n\t\t\treturn true;\n\t\t}\n\t\tswitch (layoutEditMode) {'''
if old not in s:
    raise SystemExit('old X-Men pointerDragged block not found')
s = s.replace(old, new, 1)

old = '''\t@Override\n\tpublic boolean pointerReleased(int pointer, float x, float y) {\n\t\tif (layoutVariant == TYPE_XMEN && layoutEditMode == LAYOUT_EOF) {\n\t\t\tif (pointer < 0 || pointer >= associatedKeys.length) return false;\n\t\t\tVirtualKey key = associatedKeys[pointer];\n\t\t\tif (key != null) {\n\t\t\t\tassociatedKeys[pointer] = null;\n\t\t\t\tkey.onUp();\n\t\t\t\toverlayView.postInvalidate();\n\t\t\t}\n\t\t\treturn true;\n\t\t}\n\t\tif (layoutEditMode == LAYOUT_EOF) {\n\t\t\tif (pointer >= associatedKeys.length) {'''
new = '''\t@Override\n\tpublic boolean pointerReleased(int pointer, float x, float y) {\n\t\tif (layoutVariant == TYPE_XMEN && layoutEditMode == LAYOUT_EOF) {\n\t\t\tif (pointer < 0 || pointer >= associatedKeys.length) return false;\n\t\t\tVirtualKey key = associatedKeys[pointer];\n\t\t\tassociatedKeys[pointer] = null;\n\t\t\tif (key != null) {\n\t\t\t\tkey.onUp();\n\t\t\t\toverlayView.postInvalidate();\n\t\t\t}\n\t\t\treturn true;\n\t\t}\n\t\tif (layoutEditMode == LAYOUT_EOF) {\n\t\t\tif (pointer >= associatedKeys.length) {'''
if old not in s:
    raise SystemExit('old X-Men pointerReleased block not found')
s = s.replace(old, new, 1)

p.write_text(s)
PY

cd runtime
./gradlew :app:assembleStandaloneDebug --no-daemon --stacktrace
