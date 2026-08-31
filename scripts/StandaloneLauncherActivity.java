package ru.playsoftware.j2meloader;

import android.app.Activity;
import android.content.Intent;
import android.net.Uri;
import android.os.Bundle;

import java.io.File;
import java.io.FileOutputStream;
import java.io.IOException;

import ru.playsoftware.j2meloader.config.ProfileModel;
import ru.playsoftware.j2meloader.config.ProfilesManager;
import ru.playsoftware.j2meloader.util.Constants;

public class StandaloneLauncherActivity extends Activity {
    private static final String APP_NAME = "X-Men 3 - The Last Stand";
    private static final String[] EMBEDDED_FILES = {
            "converted.dex",
            "converted.dex.conf",
            "res.jar"
    };

    @Override
    protected void onCreate(Bundle state) {
        super.onCreate(state);
        try {
            File appDir = new File(getFilesDir(), "converted/midlet");
            if (!appDir.exists() && !appDir.mkdirs()) {
                throw new IOException("Cannot create embedded game directory");
            }
            for (String name : EMBEDDED_FILES) {
                copyAsset("embedded/midlet/" + name, new File(appDir, name));
            }

            File configDir = new File(getFilesDir(), "configs/midlet");
            if (!configDir.exists() && !configDir.mkdirs()) {
                throw new IOException("Cannot create game profile directory");
            }
            File config = new File(configDir, "config.json");
            ProfileModel profile = new ProfileModel(configDir);
            profile.screenWidth = 240;
            profile.screenHeight = 320;
            profile.touchInput = true;
            profile.showKeyboard = true;
            profile.vkType = 7; // X-Men 3 custom keypad layout
            profile.vkAlpha = 190;
            profile.vkForceOpacity = true;
            profile.vkBgColor = 0x5A9EA5;
            profile.vkBgColorSelected = 0x78B7BC;
            profile.vkFgColor = 0x00334A;
            profile.vkFgColorSelected = 0xFFFFFF;
            profile.vkOutlineColor = 0xB7D9DC;
            profile.vkFeedback = true;
            profile.vkHideDelay = 0;
            profile.forceFullscreen = true;
            profile.screenScaleToFit = true;
            profile.screenKeepAspectRatio = true;
            ProfilesManager.saveConfig(profile);

            Intent intent = new Intent(this, javax.microedition.shell.MicroActivity.class);
            intent.setData(Uri.parse(appDir.getAbsolutePath()));
            intent.putExtra(Constants.KEY_MIDLET_NAME, APP_NAME);
            startActivity(intent);
            finish();
        } catch (Throwable t) {
            throw new RuntimeException("Failed to prepare embedded J2ME game", t);
        }
    }

    private void copyAsset(String asset, File target) throws IOException {
        try (java.io.InputStream in = getAssets().open(asset);
             FileOutputStream out = new FileOutputStream(target)) {
            byte[] buffer = new byte[8192];
            int read;
            while ((read = in.read(buffer)) != -1) {
                out.write(buffer, 0, read);
            }
        }
    }
}
