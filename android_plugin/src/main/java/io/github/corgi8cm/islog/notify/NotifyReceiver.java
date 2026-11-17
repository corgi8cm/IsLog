package io.github.corgi8cm.islog.notify;

import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.os.Build;

/** 鬧鐘時間到：發出通知，點一下打開遊戲。 */
public class NotifyReceiver extends BroadcastReceiver {
    static final String CHANNEL = "islog_reminders";

    @Override
    public void onReceive(Context ctx, Intent intent) {
        int id = intent.getIntExtra("id", 0);
        String title = intent.getStringExtra("title");
        String body = intent.getStringExtra("body");
        Store.remove(ctx, id);
        NotificationManager nm = (NotificationManager) ctx.getSystemService(Context.NOTIFICATION_SERVICE);
        if (nm == null) return;
        ensureChannel(nm);

        Intent open = ctx.getPackageManager().getLaunchIntentForPackage(ctx.getPackageName());
        PendingIntent content = null;
        if (open != null) {
            open.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_CLEAR_TOP);
            content = PendingIntent.getActivity(ctx, 0, open,
                    PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE);
        }

        Notification.Builder b = Build.VERSION.SDK_INT >= Build.VERSION_CODES.O
                ? new Notification.Builder(ctx, CHANNEL)
                : new Notification.Builder(ctx);
        b.setSmallIcon(R.drawable.islog_notify_icon)
                .setContentTitle(title != null ? title : "空島事記")
                .setContentText(body != null ? body : "")
                .setStyle(new Notification.BigTextStyle().bigText(body != null ? body : ""))
                .setAutoCancel(true);
        if (content != null) b.setContentIntent(content);
        try {
            nm.notify(id, b.build());
        } catch (SecurityException e) {
            // 使用者沒有允許通知：什麼都不做
        }
    }

    static void ensureChannel(NotificationManager nm) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return;
        if (nm.getNotificationChannel(CHANNEL) != null) return;
        NotificationChannel ch = new NotificationChannel(CHANNEL, "提醒", NotificationManager.IMPORTANCE_DEFAULT);
        ch.setDescription("事件提醒、每日小提醒、褪色預告");
        nm.createNotificationChannel(ch);
    }
}
