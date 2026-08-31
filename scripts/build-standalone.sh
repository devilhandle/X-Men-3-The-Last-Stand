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

p = Path('runtime/app/build.gradle')
s = p.read_text()

# Release signing is irrelevant for the debug APK and the upstream build
# otherwise eagerly requires a developer-only keystore.properties file.
s = re.sub(r'\n    signingConfigs \{.*?\n    \}\n\n    buildTypes', '\n    buildTypes', s, count=1, flags=re.S)

# Add a build-time flag available to every flavor, then enable it only for
# the standalone flavor.
s = s.replace("versionName \"1.8.2\"", "versionName \"1.8.2\"\n        buildConfigField 'boolean', 'STANDALONE', 'false'", 1)

marker = "        // variant dimension for create android port from J2ME app source\n"
flavor = '''        standalone {\n            buildConfigField 'boolean', 'STANDALONE', 'true'\n            buildConfigField 'boolean', 'FULL_EMULATOR', 'true'\n            versionNameSuffix "-standalone"\n            resValue 'string', 'app_name', 'X-Men 3 - The Last Stand'\n            proguardFiles getDefaultProguardFile('proguard-android-optimize.txt'),\n                    'proguard-rules.pro', 'proguard-common.pro'\n        }\n'''
if 'standalone {' not in s:
    s = s.replace(marker, flavor + marker, 1)

p.write_text(s)
PY

cat > "$RUNTIME/app/src/standalone/AndroidManifest.xml" <<'EOF'
<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    xmlns:tools="http://schemas.android.com/tools">
    <application>
        <activity
            android:name=".MainActivity"
            tools:node="remove" />
        <activity
            android:name="javax.microedition.shell.MicroActivity"
            android:exported="true"
            android:theme="@style/AppTheme.NoActionBar"
            android:configChanges="orientation|screenSize|keyboardHidden|screenLayout|smallestScreenSize|uiMode"
            tools:replace="android:exported,android:theme,android:configChanges,android:process"
            tools:remove="android:process">
            <intent-filter>
                <action android:name="android.intent.action.MAIN" />
                <category android:name="android.intent.category.LAUNCHER" />
            </intent-filter>
        </activity>
    </application>
</manifest>
EOF

python3 - <<'PY'
from pathlib import Path
import re

p = Path('runtime/app/src/main/java/javax/microedition/shell/MicroActivity.java')
s = p.read_text()

# Imports needed by the embedded one-time JAR -> DEX conversion.
s = s.replace('import java.io.File;\nimport java.io.IOException;\n',
              'import java.io.File;\nimport java.io.FileInputStream;\nimport java.io.FileOutputStream;\nimport java.io.IOException;\nimport java.io.InputStream;\nimport java.util.jar.JarFile;\n')
s = s.replace('import javax.microedition.lcdui.Alert;\n',
              'import com.android.dx.command.dexer.Main;\n\nimport ru.playsoftware.j2meloader.config.ProfileModel;\nimport ru.playsoftware.j2meloader.config.ProfilesManager;\n\nimport javax.microedition.lcdui.Alert;\n')

old = '''\t\tIntent intent = getIntent();
\t\tif (BuildConfig.FULL_EMULATOR) {
\t\t\tappName = intent.getStringExtra(KEY_MIDLET_NAME);
\t\t\tUri data = intent.getData();
\t\t\tif (data == null) {
\t\t\t\tshowErrorDialog("Invalid intent: app path is null");
\t\t\t\treturn;
\t\t\t}
\t\t\tappPath = data.toString();
\t\t} else {
\t\t\tappName = getTitle().toString();
\t\t\tappPath = getApplicationInfo().dataDir + "/files/converted/midlet";
\t\t\tFile dir = new File(appPath);
\t\t\tif (!dir.exists() && !dir.mkdirs()) {
\t\t\t\tthrow new RuntimeException("Can't access file system");
\t\t\t}
\t\t}
'''
new = '''\t\tIntent intent = getIntent();
\t\tif (BuildConfig.STANDALONE) {
\t\t\tappName = getString(R.string.app_name);
\t\t\tappPath = Config.getAppDir() + "/xmen3";
\t\t\ttry {
\t\t\t\tprepareStandaloneApp(appPath);
\t\t\t} catch (Exception e) {
\t\t\t\te.printStackTrace();
\t\t\t\tshowErrorDialog("Unable to prepare embedded game: " + e);
\t\t\t\treturn;
\t\t\t}
\t\t} else if (BuildConfig.FULL_EMULATOR) {
\t\t\tappName = intent.getStringExtra(KEY_MIDLET_NAME);
\t\t\tUri data = intent.getData();
\t\t\tif (data == null) {
\t\t\t\tshowErrorDialog("Invalid intent: app path is null");
\t\t\t\treturn;
\t\t\t}
\t\t\tappPath = data.toString();
\t\t} else {
\t\t\tappName = getTitle().toString();
\t\t\tappPath = getApplicationInfo().dataDir + "/files/converted/midlet";
\t\t\tFile dir = new File(appPath);
\t\t\tif (!dir.exists() && !dir.mkdirs()) {
\t\t\t\tthrow new RuntimeException("Can't access file system");
\t\t\t}
\t\t}
'''
if old not in s:
    raise SystemExit('MicroActivity launch block not found')
s = s.replace(old, new, 1)

marker = '\tpublic void lockNightMode() {'
method = r'''	private void prepareStandaloneApp(String appPath) throws Exception {
		File appDir = new File(appPath);
		File configDir = new File(Config.getConfigsDir(), appDir.getName());
		File dexFile = new File(appDir, Config.MIDLET_DEX_FILE);
		File manifestFile = new File(appDir, Config.MIDLET_MANIFEST_FILE);
		File resFile = new File(appDir, Config.MIDLET_RES_FILE);
		File profileFile = new File(configDir, Config.MIDLET_CONFIG_FILE);

		if (dexFile.isFile() && manifestFile.isFile() && resFile.isFile() && profileFile.isFile()) {
			return;
		}
		if (!appDir.exists() && !appDir.mkdirs()) {
			throw new IOException("Can't create standalone app directory: " + appDir);
		}
		if (!configDir.exists() && !configDir.mkdirs()) {
			throw new IOException("Can't create standalone profile directory: " + configDir);
		}

		File jarFile = new File(getCacheDir(), "X-Men3-TheLastStand.jar");
		try (InputStream in = getAssets().open("embedded/X-Men3-TheLastStand.jar");
			 FileOutputStream out = new FileOutputStream(jarFile)) {
			byte[] buffer = new byte[8192];
			int count;
			while ((count = in.read(buffer)) != -1) {
				out.write(buffer, 0, count);
			}
		}

		Main.main(new String[]{
				"--no-optimize",
				"--core-library",
				"--output=" + dexFile.getAbsolutePath(),
				jarFile.getAbsolutePath()
		});

		try (FileInputStream in = new FileInputStream(jarFile);
			 FileOutputStream out = new FileOutputStream(resFile)) {
			byte[] buffer = new byte[8192];
			int count;
			while ((count = in.read(buffer)) != -1) {
				out.write(buffer, 0, count);
			}
		}

		JarFile jar = new JarFile(jarFile);
		try (InputStream in = jar.getInputStream(jar.getJarEntry(JarFile.MANIFEST_NAME));
			 FileOutputStream out = new FileOutputStream(manifestFile)) {
			byte[] buffer = new byte[8192];
			int count;
			while ((count = in.read(buffer)) != -1) {
				out.write(buffer, 0, count);
			}
		} finally {
			jar.close();
		}

		ProfileModel defaults = new ProfileModel(configDir);
		defaults.showKeyboard = false;
		defaults.touchInput = true;
		defaults.forceFullscreen = true;
		ProfilesManager.saveConfig(defaults);
	}

'''
if 'private void prepareStandaloneApp' not in s:
    s = s.replace(marker, method + marker, 1)

p.write_text(s)
PY

chmod +x "$RUNTIME/gradlew"
"$RUNTIME/gradlew" :app:assembleStandaloneDebug --no-daemon --stacktrace
