package io.github.corgi8cm.islog.notify;

import android.app.AlarmManager;
import android.app.PendingIntent;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;

import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

/** 記住排了哪些通知（重新開機後要重排、換一批時要取消舊的），並負責排程系統鬧鐘。 */
final class Store {
    private static final String PREFS = "islog_notify";
    private static final String KEY = "items";

    private Store() {}

    static JSONArray load(Context ctx) {
        SharedPreferences p = ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE);
        try {
            return new JSONArray(p.getString(KEY, "[]"));
        } catch (JSONException e) {
            return new JSONArray();
        }
    }

    static void save(Context ctx, JSONArray items) {
        ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().putString(KEY, items.toString()).apply();
    }

    static PendingIntent pending(Context ctx, int id, String title, String body) {
        Intent intent = new Intent(ctx, NotifyReceiver.class);
        intent.putExtra("id", id);
        intent.putExtra("title", title);
        intent.putExtra("body", body);
        return PendingIntent.getBroadcast(ctx, id, intent,
                PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE);
    }

    /** 取消之前排的全部通知。 */
    static void cancelAll(Context ctx) {
        AlarmManager am = (AlarmManager) ctx.getSystemService(Context.ALARM_SERVICE);
        JSONArray old = load(ctx);
        for (int i = 0; i < old.length(); i++) {
            JSONObject it = old.optJSONObject(i);
            if (it == null) continue;
            PendingIntent pi = pending(ctx, it.optInt("id"), "", "");
            if (am != null) am.cancel(pi);
            pi.cancel();
        }
        save(ctx, new JSONArray());
    }

    /**
     * 排程一批通知。不需要「精確鬧鐘」權限：系統可能晚幾分鐘發，對提醒小事來說夠用。
     */
    static void scheduleAll(Context ctx, JSONArray items) {
        AlarmManager am = (AlarmManager) ctx.getSystemService(Context.ALARM_SERVICE);
        long now = System.currentTimeMillis();
        JSONArray kept = new JSONArray();
        for (int i = 0; i < items.length(); i++) {
            JSONObject it = items.optJSONObject(i);
            if (it == null) continue;
            long at = it.optLong("at");
            if (at <= now) continue;
            PendingIntent pi = pending(ctx, it.optInt("id"), it.optString("title"), it.optString("body"));
            if (am != null) am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, pi);
            kept.put(it);
        }
        save(ctx, kept);
    }

    /** 發出去的通知從清單拿掉。 */
    static void remove(Context ctx, int id) {
        JSONArray old = load(ctx);
        JSONArray kept = new JSONArray();
        for (int i = 0; i < old.length(); i++) {
            JSONObject it = old.optJSONObject(i);
            if (it != null && it.optInt("id") != id) kept.put(it);
        }
        save(ctx, kept);
    }
}
