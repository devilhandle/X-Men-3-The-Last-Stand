#!/usr/bin/env bash
set -euo pipefail

GAME_JAR="X-Men3-TheLastStand_s40v3a.jar"
RUNTIME="runtime"

rm -rf "$RUNTIME"
git clone --depth 1 https://github.com/nikita36078/J2ME-Loader.git "$RUNTIME"
chmod +x "$RUNTIME/gradlew"
mkdir -p "$RUNTIME/app/src/main/assets/embedded/midlet"
mkdir -p "$RUNTIME/app/src/standalone"
mkdir -p "$RUNTIME/app/src/main/java/ru/playsoftware/j2meloader"
cp scripts/StandaloneLauncherActivity.java "$RUNTIME/app/src/main/java/ru/playsoftware/j2meloader/StandaloneLauncherActivity.java"

keytool -genkeypair -v \
  -keystore "$RUNTIME/standalone-debug.keystore" \
  -storepass android \
  -alias androiddebugkey \
  -keypass android \
  -keyalg RSA \
  -keysize 2048 \
  -validity 10000 \
  -dname "CN=Android Debug,O=Android,C=US" >/dev/null 2>&1
cat > "$RUNTIME/keystore.properties" <<EOF
keyAlias=androiddebugkey
keyPassword=android
storeFile=$RUNTIME/standalone-debug.keystore
storePassword=android
EOF

# Install the X-Men-only virtual keyboard into the standalone runtime.
python3 - <<'PY'
from pathlib import Path
p = Path('runtime/app/src/main/java/javax/microedition/lcdui/keyboard/VirtualKeyboard.java')
s = p.read_text()

s = s.replace(
    'private static final int TYPE_ARROWS = 6;',
    'private static final int TYPE_ARROWS = 6;\n\tprivate static final int TYPE_XMEN = 7;',
    1,
)

start = s.find('\t\t\tcase TYPE_XMEN:')
if start != -1:
    end = s.find('\t\t\tcase TYPE_NUM_ARR:', start)
    if end != -1:
        s = s[:start] + s[end:]

needle = '\t\t\tcase TYPE_NUM_ARR:\n\t\t\tdefault:'
case = '''\t\t\tcase TYPE_XMEN:\n\t\t\t\t// Only the requested X-Men controls are visible. No phone, numeric,\n\t\t\t\t// emulator or default keypad is allowed to appear.\n\t\t\t\tArrays.fill(keyScales, 1.0f);\n\t\t\t\tfor (VirtualKey key : keypad) key.visible = false;\n\n\t\t\t\t// L and R at the upper edge.\n\t\t\t\tsetSnap(KEY_SOFT_LEFT, SCREEN, RectSnap.INT_NORTHWEST, true);\n\t\t\t\tsetSnap(KEY_SOFT_RIGHT, SCREEN, RectSnap.INT_NORTHEAST, true);\n\n\t\t\t\t// Supplied keypad: home/up symbol, left, right and down at the bottom-left.\n\t\t\t\tsetSnap(KEY_UP, SCREEN, RectSnap.INT_SOUTHWEST, true);\n\t\t\t\tsetSnap(KEY_LEFT, KEY_UP, RectSnap.EXT_WEST, true);\n\t\t\t\tsetSnap(KEY_RIGHT, KEY_UP, RectSnap.EXT_EAST, true);\n\t\t\t\tsetSnap(KEY_DOWN, KEY_UP, RectSnap.EXT_SOUTH, true);\n\n\t\t\t\t// 5 in the lower-right/middle and pause in the bottom-right.\n\t\t\t\tsetSnap(KEY_NUM5, SCREEN, RectSnap.INT_EAST, true);\n\t\t\t\tsetSnap(KEY_FIRE, SCREEN, RectSnap.INT_SOUTHEAST, true);\n\t\t\t\tbreak;\n\t\t\tcase TYPE_NUM_ARR:\n\t\t\tdefault:'''
if needle not in s:
    raise SystemExit('X-Men keypad insertion point not found')
s = s.replace(needle, case, 1)

# The supplied image uses a home-shaped symbol for the upper-left directional button.
s = s.replace(
    'keypad[KEY_UP] = new VirtualKey(Canvas.KEY_UP, ARROW_UP);',
    'keypad[KEY_UP] = new VirtualKey(Canvas.KEY_UP, "⌂");',
    1,
)
# The supplied image uses a pause symbol rather than the generic F label.
s = s.replace(
    'keypad[KEY_FIRE] = new VirtualKey(Canvas.KEY_FIRE, "F");',
    'keypad[KEY_FIRE] = new VirtualKey(Canvas.KEY_FIRE, "Ⅱ");',
    1,
)
p.write_text(s)
PY

# Make the standalone activity the only launcher.
python3 - <<'PY'
from pathlib import Path
p = Path('runtime/app/src/main/AndroidManifest.xml')
s = p.read_text()
launcher = '''            <intent-filter>\n                <action android:name="android.intent.action.MAIN" />\n\n                <category android:name="android.intent.category.LAUNCHER" />\n            </intent-filter>\n'''
s = s.replace(launcher, '', 1)
activity = '''        <activity\n            android:name=".StandaloneLauncherActivity"\n            android:exported="true"\n            android:theme="@style/AppTheme.NoActionBar"\n            android:screenOrientation="landscape"\n            android:configChanges="orientation|screenSize|keyboardHidden|screenLayout|smallestScreenSize|uiMode">\n            <intent-filter>\n                <action android:name="android.intent.action.MAIN" />\n                <category android:name="android.intent.category.LAUNCHER" />\n            </intent-filter>\n        </activity>\n'''
marker = '        <activity\n            android:name="javax.microedition.shell.MicroActivity"'
if '.StandaloneLauncherActivity' not in s:
    if marker not in s:
        raise SystemExit('MicroActivity manifest marker not found')
    s = s.replace(marker, activity + marker, 1)
p.write_text(s)
PY

cd "$RUNTIME"
./gradlew :dexlib:assembleDebug --no-daemon
cd ..

DX_AAR="$RUNTIME/dexlib/build/outputs/aar/dexlib-debug.aar"
DX_JAR="$(mktemp --suffix=.jar)"
unzip -p "$DX_AAR" classes.jar > "$DX_JAR"
ZIP4J_JAR="$(find "$HOME/.gradle/caches/modules-2/files-2.1/net.lingala.zip4j/zip4j/2.10.0" -name 'zip4j-2.10.0.jar' -print -quit)"
ASM_JAR="$(find "$HOME/.gradle/caches/modules-2/files-2.1/org.ow2.asm/asm/9.8" -name 'asm-9.8.jar' -print -quit)"
if [[ -z "$ZIP4J_JAR" || -z "$ASM_JAR" ]]; then
  echo "Required dexlib dependencies were not found"
  exit 1
fi

java -cp "$DX_JAR:$ZIP4J_JAR:$ASM_JAR" \
  com.android.dx.command.dexer.Main \
  --no-optimize --core-library \
  --output="$RUNTIME/app/src/main/assets/embedded/midlet/converted.dex" \
  "$GAME_JAR"

cp "$GAME_JAR" "$RUNTIME/app/src/main/assets/embedded/midlet/res.jar"
unzip -p "$GAME_JAR" META-INF/MANIFEST.MF > "$RUNTIME/app/src/main/assets/embedded/midlet/converted.dex.conf"
rm -f "$DX_JAR"

python3 - <<'PY'
from pathlib import Path
import re
p=Path('runtime/app/build.gradle')
s=p.read_text()
s=re.sub(r'\n    signingConfigs \{.*?\n    \}\n\n    buildTypes','\n    buildTypes',s,count=1,flags=re.S)
s=s.replace('            signingConfig signingConfigs.release\n','')
if "buildConfigField 'boolean', 'STANDALONE'" not in s:
    s=s.replace('        versionName "1.8.2"','        versionName "1.8.2"\n        buildConfigField \'boolean\', \'STANDALONE\', \'false\'',1)
marker='        // variant dimension for create android port from J2ME app source\n'
flavor='''        standalone {\n            buildConfigField 'boolean', 'STANDALONE', 'true'\n            buildConfigField 'boolean', 'FULL_EMULATOR', 'true'\n            versionNameSuffix "-standalone"\n            resValue 'string', 'app_name', 'X-Men 3 - The Last Stand'\n            proguardFiles getDefaultProguardFile('proguard-android-optimize.txt'),\n                    'proguard-rules.pro', 'proguard-common.pro'\n        }\n'''
if '        standalone {' not in s:
    s=s.replace(marker,flavor+marker,1)
p.write_text(s)
PY

chmod +x "$RUNTIME/gradlew"
cd "$RUNTIME"
./gradlew :app:assembleStandaloneDebug --no-daemon --stacktrace
