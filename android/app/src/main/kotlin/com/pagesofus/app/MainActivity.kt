package com.pagesofus.app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.app.KeyguardManager
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.os.BatteryManager
import android.os.Build
import android.os.Bundle
import android.os.PowerManager
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: AudioServiceActivity() {
    private val DEVICE_STATUS_CHANNEL = "com.pagesofus.app/device_status"
    private val PREFS_NAME = "pages_of_us_telemetry"
    private val KEY_LAST_UNLOCKED = "last_unlocked_at_ms"
    private var screenReceiver: BroadcastReceiver? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        registerScreenStateReceiver()
        recordUnlockIfInteractive()
    }

    override fun onResume() {
        super.onResume()
        recordUnlockIfInteractive()
    }

    override fun onDestroy() {
        try {
            screenReceiver?.let { unregisterReceiver(it) }
        } catch (_: Exception) {}
        screenReceiver = null
        super.onDestroy()
    }

    private fun registerScreenStateReceiver() {
        if (screenReceiver != null) return
        val filter = IntentFilter().apply {
            addAction(Intent.ACTION_USER_PRESENT)
            addAction(Intent.ACTION_SCREEN_ON)
            addAction(Intent.ACTION_SCREEN_OFF)
        }
        screenReceiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context?, intent: Intent?) {
                val action = intent?.action ?: return
                if (action == Intent.ACTION_USER_PRESENT) {
                    saveLastUnlockedNow()
                } else if (action == Intent.ACTION_SCREEN_ON) {
                    recordUnlockIfInteractive()
                }
            }
        }
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                registerReceiver(screenReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
            } else {
                registerReceiver(screenReceiver, filter)
            }
        } catch (_: Exception) {}
    }

    private fun recordUnlockIfInteractive() {
        try {
            val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
            val km = getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager
            if (pm.isInteractive && !km.isKeyguardLocked) {
                saveLastUnlockedNow()
            }
        } catch (_: Exception) {}
    }

    private fun saveLastUnlockedNow() {
        getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .edit()
            .putLong(KEY_LAST_UNLOCKED, System.currentTimeMillis())
            .apply()
    }

    private fun readBatteryInfo(): Pair<Int, Boolean> {
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
        return Pair(levelPercent, isCharging)
    }

    private fun readNetworkType(): String {
        return try {
            val cm = applicationContext.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                val net = cm.activeNetwork ?: return "offline"
                val caps = cm.getNetworkCapabilities(net) ?: return "offline"
                when {
                    caps.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) -> "wifi"
                    caps.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR) -> "mobile"
                    caps.hasTransport(NetworkCapabilities.TRANSPORT_ETHERNET) -> "wifi"
                    else -> "online"
                }
            } else {
                @Suppress("DEPRECATION")
                val info = cm.activeNetworkInfo
                if (info == null || !info.isConnected) "offline"
                else if (info.type == ConnectivityManager.TYPE_WIFI) "wifi"
                else "mobile"
            }
        } catch (_: Exception) {
            "unknown"
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, DEVICE_STATUS_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getBatteryStatus" -> {
                        try {
                            val (levelPercent, isCharging) = readBatteryInfo()
                            result.success(
                                mapOf(
                                    "level" to levelPercent,
                                    "isCharging" to isCharging
                                )
                            )
                        } catch (e: Exception) {
                            result.error("BATTERY_ERROR", e.message, null)
                        }
                    }
                    "getFullTelemetry" -> {
                        try {
                            val (levelPercent, isCharging) = readBatteryInfo()
                            val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
                            val km = getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager
                            val isScreenOn = pm.isInteractive
                            val isUnlocked = isScreenOn && !km.isKeyguardLocked
                            if (isUnlocked) {
                                saveLastUnlockedNow()
                            }
                            val lastUnlockedMs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                                .getLong(KEY_LAST_UNLOCKED, 0L)
                            val netType = readNetworkType()

                            result.success(
                                mapOf(
                                    "level" to levelPercent,
                                    "isCharging" to isCharging,
                                    "isScreenOn" to isScreenOn,
                                    "isDeviceUnlocked" to isUnlocked,
                                    "lastUnlockedAtMs" to if (lastUnlockedMs > 0L) lastUnlockedMs else null,
                                    "networkType" to netType
                                )
                            )
                        } catch (e: Exception) {
                            result.error("TELEMETRY_ERROR", e.message, null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
