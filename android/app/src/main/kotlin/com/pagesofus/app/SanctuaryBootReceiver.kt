package com.pagesofus.app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

class SanctuaryBootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context?, intent: Intent?) {
        val ctx = context ?: return
        val action = intent?.action ?: return
        if (action == Intent.ACTION_BOOT_COMPLETED || action == Intent.ACTION_MY_PACKAGE_REPLACED) {
            SanctuaryTelemetryStore.ensureDayAndArchiveIfNeeded(ctx)
            SanctuaryTelemetryService.start(ctx)
        }
    }
}
