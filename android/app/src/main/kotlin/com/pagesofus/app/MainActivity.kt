package com.pagesofus.app

import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.BatteryManager
import android.os.Build
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: AudioServiceActivity() {
    private val DEVICE_STATUS_CHANNEL = "com.pagesofus.app/device_status"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, DEVICE_STATUS_CHANNEL)
            .setMethodCallHandler { call, result ->
                if (call.method == "getBatteryStatus") {
                    try {
                        val batteryStatus: Intent? = IntentFilter(Intent.ACTION_BATTERY_CHANGED).let { ifilter ->
                            applicationContext.registerReceiver(null, ifilter)
                        }
                        val status = batteryStatus?.getIntExtra(BatteryManager.EXTRA_STATUS, -1) ?: -1
                        val isCharging = status == BatteryManager.BATTERY_STATUS_CHARGING ||
                            status == BatteryManager.BATTERY_STATUS_FULL

                        var levelPercent = -1
                        val level = batteryStatus?.getIntExtra(BatteryManager.EXTRA_LEVEL, -1) ?: -1
                        val scale = batteryStatus?.getIntExtra(BatteryManager.EXTRA_SCALE, -1) ?: -1
                        if (level >= 0 && scale > 0) {
                            levelPercent = (level * 100) / scale
                        } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                            val bm = applicationContext.getSystemService(Context.BATTERY_SERVICE) as BatteryManager
                            levelPercent = bm.getIntProperty(BatteryManager.BATTERY_PROPERTY_CAPACITY)
                        }

                        result.success(
                            mapOf(
                                "level" to levelPercent,
                                "isCharging" to isCharging
                            )
                        )
                    } catch (e: Exception) {
                        result.error("BATTERY_ERROR", e.message, null)
                    }
                } else {
                    result.notImplemented()
                }
            }
    }
}
