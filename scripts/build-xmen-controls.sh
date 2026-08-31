#!/usr/bin/env bash
set -euo pipefail

# Build the standalone X-Men APK, then use the supplied PNG as the visual
# keypad overlay at the bottom of the game. Existing X-Men key hitboxes remain.
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
pattern = re.compile(r'\t@Override\n\tpublic void paint\(CanvasWrapper g\) \{.*?\n\t\}\n\n\t@Override\n\tpublic boolean pointerPressed', re.S)
match = pattern.search(s)
if not match:
    raise SystemExit('VirtualKeyboard paint method not found')
paint = '''\t@Override\n\tpublic void paint(CanvasWrapper g) {\n\t\tif (!visible) return;\n\t\t// Use the supplied button artwork at the bottom of the game.\n\t\tfloat overlayHeight = screen.height() * 0.38f;\n\t\tRectF dst = new RectF(screen.left, screen.bottom - overlayHeight,\n\t\t\t\tscreen.right, screen.bottom);\n\t\tg.drawAssetBitmap("xmen_buttons.png", dst);\n\t}\n\n\t@Override\n\tpublic boolean pointerPressed'''
s = s[:match.start()] + paint + s[match.end():]
p.write_text(s)
PY

cd runtime
./gradlew :app:assembleStandaloneDebug --no-daemon --stacktrace
