package io.github.corgi8cm.islog.notify;

import android.Manifest;
import android.app.Activity;
import android.app.NotificationManager;
import android.content.Context;
import android.content.pm.PackageManager;
import android.os.Build;

import org.godotengine.godot.Godot;
import org.godotengine.godot.plugin.GodotPlugin;
import org.godotengine.godot.plugin.UsedByGodot;
import org.json.JSONArray;
import org.json.JSONException;

/**
 * Godot 外掛：GDScript 用 Engine.get_singleton("IslogNotify") 呼叫。
 * 遊戲每次存檔後把接下來要發的通知整批交過來（scheduleJson），這裡取消舊的、排新的。
 */
public class IslogNotify extends GodotPlugin {
    private static final int PERMISSION_REQUEST = 4242;

    public IslogNotify(Godot godot) {
        super(godot);
    }

    @Override
    public String getPluginName() {
        return "IslogNotify";
    }

    private Context context() {
        Activity a = getActivity();
        return a != null ? a.getApplicationContext() : null;
    }

    @UsedByGodot
    public boolean hasPermission() {
        Context ctx = context();
        if (ctx == null) return false;
        if (Build.VERSION.SDK_INT >= 33) {
            return ctx.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED;
        }
        NotificationManager nm = (NotificationManager) ctx.getSystemService(Context.NOTIFICATION_SERVICE);
        return nm == null || nm.areNotificationsEnabled();
    }

    @UsedByGodot
    public void requestPermission() {
        final Activity a = getActivity();
        if (a == null || Build.VERSION.SDK_INT < 33 || hasPermission()) return;
        a.runOnUiThread(() -> a.requestPermissions(
                new String[] {Manifest.permission.POST_NOTIFICATIONS}, PERMISSION_REQUEST));
    }

    /** items：[{id, at（毫秒）, title, body}]。 */
    @UsedByGodot
    public void scheduleJson(String json) {
        Context ctx = context();
        if (ctx == null) return;
        JSONArray items;
        try {
            items = new JSONArray(json);
        } catch (JSONException e) {
            return;
        }
        Store.cancelAll(ctx);
        Store.scheduleAll(ctx, items);
    }

    @UsedByGodot
    public void cancelAll() {
        Context ctx = context();
        if (ctx != null) Store.cancelAll(ctx);
    }
}
