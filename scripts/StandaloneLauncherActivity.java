package ru.playsoftware.j2meloader;

import android.app.Activity;
import android.content.Intent;
import android.net.Uri;
import android.os.Bundle;

import java.io.DataOutputStream;
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

            // The supplied layout is a J2ME-Loader custom layout.  Recreate the
            // actual layout file here so the runtime uses the same positions,
            // while keeping the requested X-Men controls: L, R, 5 and pause.
            writeXMenKeyboardLayout(new File(configDir, "VirtualKeyboardLayout"));

            ProfileModel profile = new ProfileModel(configDir);
            profile.screenWidth = 240;
            profile.screenHeight = 320;
            profile.touchInput = true;
            profile.showKeyboard = true;
            profile.vkType = 0; // TYPE_CUSTOM: load VirtualKeyboardLayout above
            profile.vkAlpha = 220;
            profile.vkForceOpacity = false;
            profile.vkBgColor = 0x2F5B5E;
            profile.vkBgColorSelected = 0x3E7478;
            profile.vkFgColor = 0x042A3D;
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

    private void writeXMenKeyboardLayout(File file) throws IOException {
        // VirtualKeyboard layout format: VKL signature, version 3,
        // key block, scale block, EOF.  All 28 keys are specified so the
        // upstream default layout cannot leak any unwanted buttons through.
        final int VKL_SIGNATURE = 0x564B4C00;
        final int TYPE_BLOCK = 0;
        final int SCALES_BLOCK = 1;
        final int EOF_BLOCK = -1;

        // Key hashes are VirtualKey.hashCode() = 31 * (31 + keyCode).
        final int[] hashes = {
                2480, 2511, 2542, 2573, 2604, 2635, 2666, 2697, 2728, 2449,
                2263, 2046, 775, 744, 651, 620, 927, 930, 926, 868, 837, 896,
                899, 895, 806, 1000001, 1000002, 1000003
        };

        // Only these eight controls are visible:
        // L above UP, R above the right-side action area, D-pad, 5 and pause.
        final boolean[] visible = new boolean[28];
        visible[12] = true; // L
        visible[13] = true; // R
        visible[4] = true;  // 5
        visible[17] = true; // UP
        visible[19] = true; // LEFT
        visible[20] = true; // RIGHT
        visible[22] = true; // DOWN
        visible[24] = true; // pause / FIRE

        // RectSnap constants used by the upstream runtime.
        final int INT_NORTHWEST = 0x00020002;
        final int INT_NORTHEAST = 0x00020008;
        final int INT_EAST = 0x00040008;
        final int INT_SOUTHEAST = 0x00080008;
        final int EXT_SOUTHWEST = 0x00100001;
        final int EXT_SOUTH = 0x00100004;
        final int EXT_SOUTHEAST = 0x00100010;

        final int[] origin = new int[28];
        final int[] snap = new int[28];
        for (int i = 0; i < 28; i++) {
            origin[i] = -1;
            snap[i] = INT_NORTHWEST;
        }

        // Layout matching the supplied visual: L/R above, D-pad lower-left,
        // 5 mid-right and pause lower-right.
        origin[12] = -1; snap[12] = INT_NORTHWEST; // L
        origin[13] = -1; snap[13] = INT_NORTHEAST; // R
        origin[17] = 12; snap[17] = EXT_SOUTH; // UP below L
        origin[19] = 17; snap[19] = EXT_SOUTHWEST; // LEFT
        origin[20] = 17; snap[20] = EXT_SOUTHEAST; // RIGHT
        origin[22] = 19; snap[22] = EXT_SOUTH; // DOWN
        origin[4] = -1; snap[4] = INT_EAST; // 5
        origin[24] = -1; snap[24] = INT_SOUTHEAST; // pause

        try (DataOutputStream out = new DataOutputStream(new FileOutputStream(file))) {
            out.writeInt(VKL_SIGNATURE);
            out.writeInt(3);

            out.writeInt(TYPE_BLOCK);
            out.writeInt(4 + 28 * 21);
            out.writeInt(28);
            for (int i = 0; i < 28; i++) {
                out.writeInt(hashes[i]);
                out.writeBoolean(visible[i]);
                out.writeInt(origin[i]);
                out.writeInt(snap[i]);
                out.writeFloat(0f);
                out.writeFloat(0f);
            }

            out.writeInt(SCALES_BLOCK);
            out.writeInt(4 + 5 * 4);
            out.writeInt(5);
            out.writeFloat(1f);
            out.writeFloat(1f);
            out.writeFloat(1f);
            out.writeFloat(1f);
            out.writeFloat(1f);

            out.writeInt(EOF_BLOCK);
            out.writeInt(0);
        }
    }
}
