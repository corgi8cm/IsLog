package io.github.corgi8cm.islog.notify;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;

/** 重新開機後系統鬧鐘會清掉：把記住的通知重新排一次。 */
public class BootReceiver extends BroadcastReceiver {
    @Override
    public void onReceive(Context ctx, Intent intent) {
        if (!Intent.ACTION_BOOT_COMPLETED.equals(intent.getAction())) return;
        Store.scheduleAll(ctx, Store.load(ctx));
    }
}
