#!/usr/bin/env bash
set -euo pipefail

GAME_JAR="X-Men3-TheLastStand_s40v3a.jar"
RUNTIME="runtime"

rm -rf "$RUNTIME"
git clone --depth 1 https://github.com/nikita36078/J2ME-Loader.git "$RUNTIME"
mkdir -p "$RUNTIME/app/src/main/assets/embedded/midlet"
mkdir -p "$RUNTIME/app/src/standalone"

# Build the bundled J2ME Loader dexlib so the same converter used by J2ME Loader
# can convert the original MIDlet JAR into the runtime's converted.dex format.
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

mkdir -p "$RUNTIME/app/src/main/assets/embedded/midlet"
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
flavor='''        standalone {
            buildConfigField 'boolean', 'STANDALONE', 'true'
            buildConfigField 'boolean', 'FULL_EMULATOR', 'true'
            versionNameSuffix "-standalone"
            resValue 'string', 'app_name', 'X-Men 3 - The Last Stand'
            proguardFiles getDefaultProguardFile('proguard-android-optimize.txt'),
                    'proguard-rules.pro', 'proguard-common.pro'
        }
'''
if '        standalone {' not in s:
    s=s.replace(marker,flavor+marker,1)
p.write_text(s)
PY

cat > "$RUNTIME/app/src/standalone/AndroidManifest.xml" <<'EOF'
<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android" xmlns:tools="http://schemas.android.com/tools">
 <application>
  <activity android:name=".MainActivity" tools:node="remove" />
  <activity android:name="javax.microedition.shell.MicroActivity" android:exported="true" tools:remove="android:process" tools:replace="android:exported">
   <intent-filter>
    <action android:name="android.intent.action.MAIN"/>
    <category android:name="android.intent.category.LAUNCHER"/>
   </intent-filter>
  </activity>
  <activity android:name=".settings.SettingsActivity" tools:node="remove" />
  <activity android:name=".donations.DonationsActivity" tools:node="remove" />
  <activity android:name=".settings.KeyMapperActivity" tools:node="remove" />
  <activity android:name=".filepicker.FilteredFilePickerActivity" tools:node="remove" />
  <activity android:name=".config.ProfilesActivity" tools:node="remove" />
  <provider android:name="androidx.core.content.FileProvider" android:authorities="${applicationId}.provider" tools:node="remove" />
 </application>
</manifest>
EOF

chmod +x "$RUNTIME/gradlew"
cd "$RUNTIME"
./gradlew :app:assembleStandaloneDebug --no-daemon --stacktrace
