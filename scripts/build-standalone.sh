#!/usr/bin/env bash
set -euo pipefail

GAME_JAR="X-Men3-TheLastStand_s40v3a.jar"
RUNTIME="runtime"

git clone --depth 1 https://github.com/nikita36078/J2ME-Loader.git "$RUNTIME"
mkdir -p "$RUNTIME/app/src/main/assets/embedded"
mkdir -p "$RUNTIME/app/src/standalone"
cp "$GAME_JAR" "$RUNTIME/app/src/main/assets/embedded/X-Men3-TheLastStand.jar"

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
if '        standalone {' not in s: s=s.replace(marker,flavor+marker,1)
p.write_text(s)
PY

cat > "$RUNTIME/app/src/standalone/AndroidManifest.xml" <<'EOF'
<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android" xmlns:tools="http://schemas.android.com/tools">
 <application>
  <activity android:name=".MainActivity" tools:node="remove" />
  <activity android:name="javax.microedition.shell.MicroActivity" android:exported="true" android:theme="@style/AppTheme.NoActionBar" android:configChanges="orientation|screenSize|keyboardHidden|screenLayout|smallestScreenSize|uiMode" tools:replace="android:exported,android:theme,android:configChanges,android:process" tools:remove="android:process">
   <intent-filter><action android:name="android.intent.action.MAIN"/><category android:name="android.intent.category.LAUNCHER"/></intent-filter>
  </activity>
 </application>
</manifest>
EOF

chmod +x "$RUNTIME/gradlew"
cd "$RUNTIME"
./gradlew :app:assembleStandaloneDebug --no-daemon --stacktrace
