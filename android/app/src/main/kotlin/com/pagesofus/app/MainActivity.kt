package com.pagesofus.app

import android.Manifest
import android.app.KeyguardManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
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
    private val KEY_UNLOCK_COUNT = "unlock_count_today"
    private val KEY_UNLOCK_DATE = "unlock_count_date"
    private val KEY_STEP_DATE = "step_count_date"
    private val KEY_STEP_LAST_RAW = "step_last_raw"
    private val KEY_STEP_TODAY = "step_today_total"
    private val KEY_STEP_HAS_BASELINE = "step_has_baseline"
    private var screenReceiver: BroadcastReceiver? = null
    private var sensorManager: SensorManager? = null
    private var stepSensor: Sensor? = null
    private var stepListener: SensorEventListener? = null
    private var stepListenerRegistered = false
    private var telemetryChannel: MethodChannel? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        registerScreenStateReceiver()
        recordUnlockIfInteractive()
        registerStepCounterListener()
    }

    override fun onResume() {
        super.onResume()
        recordUnlockIfInteractive()
        registerStepCounterListener()
    }

    override fun onDestroy() {
        try {
            screenReceiver?.let { unregisterReceiver(it) }
        } catch (_: Exception) {}
        screenReceiver = null
        try {
            stepListener?.let { sensorManager?.unregisterListener(it) }
        } catch (_: Exception) {}
        stepListenerRegistered = false
        super.onDestroy()
    }

    private fun hasActivityRecognitionPermission(): Boolean {
        return Build.VERSION.SDK_INT < Build.VERSION_CODES.Q ||
            checkSelfPermission(Manifest.permission.ACTIVITY_RECOGNITION) == PackageManager.PERMISSION_GRANTED
    }

    private fun initStepSensor() {
        if (sensorManager == null) {
            sensorManager = getSystemService(Context.SENSOR_SERVICE) as? SensorManager
        }
        if (stepSensor == null) {
            stepSensor = sensorManager?.getDefaultSensor(Sensor.TYPE_STEP_COUNTER)
        }
    }

    private fun registerStepCounterListener(): Boolean {
        initStepSensor()
        val sensor = stepSensor ?: return false
        val sm = sensorManager ?: return false
        if (!hasActivityRecognitionPermission()) return false

        if (stepListener == null) {
            stepListener = object : SensorEventListener {
                override fun onSensorChanged(event: SensorEvent?) {
                    if (event?.sensor?.type == Sensor.TYPE_STEP_COUNTER && event.values.isNotEmpty()) {
                        recordStepRawValue(event.values[0].toInt())
                    }
                }

                override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {}
            }
        }

        if (stepListenerRegistered) {
            try {
                stepListener?.let { sm.flush(it) }
            } catch (_: Exception) {}
            return true
        }

        return try {
            val registered = sm.registerListener(stepListener, sensor, SensorManager.SENSOR_DELAY_UI, 0)
            stepListenerRegistered = registered
            registered
        } catch (_: Exception) {
            false
        }
    }

    private fun recordStepRawValue(raw: Int) {
        if (raw < 0) return
        val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val today = todayDateKey()
        val storedDate = prefs.getString(KEY_STEP_DATE, "")
        val hasBaseline = prefs.getBoolean(KEY_STEP_HAS_BASELINE, false)

        if (storedDate != today || !hasBaseline) {
            prefs.edit()
                .putString(KEY_STEP_DATE, today)
                .putBoolean(KEY_STEP_HAS_BASELINE, true)
                .putInt(KEY_STEP_LAST_RAW, raw)
                .putInt(KEY_STEP_TODAY, 0)
                .apply()
            return
        }

        val lastRaw = prefs.getInt(KEY_STEP_LAST_RAW, raw)
        val todayTotal = prefs.getInt(KEY_STEP_TODAY, 0)
        // Handle device reboot seamlessly when hardware counter resets below lastRaw
        val delta = if (raw >= lastRaw) (raw - lastRaw) else raw
        val updatedTotal = if (delta > 0) todayTotal + delta else todayTotal

        prefs.edit()
            .putInt(KEY_STEP_LAST_RAW, raw)
            .putInt(KEY_STEP_TODAY, updatedTotal)
            .apply()

        if (delta > 0) {
            runOnUiThread {
                try {
                    telemetryChannel?.invokeMethod("onStepsChanged", mapOf("stepsToday" to updatedTotal))
                } catch (_: Exception) {}
            }
        }
    }

    private fun readHardwareStepsToday(): Int? {
        initStepSensor()
        if (stepSensor == null || !hasActivityRecognitionPermission()) {
            return null
        }
        registerStepCounterListener()
        val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val today = todayDateKey()
        val storedDate = prefs.getString(KEY_STEP_DATE, "")
        val hasBaseline = prefs.getBoolean(KEY_STEP_HAS_BASELINE, false)
        return if (storedDate == today && hasBaseline) {
            prefs.getInt(KEY_STEP_TODAY, 0)
        } else {
            0
        }
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
                    saveLastUnlockedNow(incrementCount = true)
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
                saveLastUnlockedNow(incrementCount = false)
            }
        } catch (_: Exception) {}
    }

    private fun todayDateKey(): String {
        val cal = java.util.Calendar.getInstance()
        return "${cal.get(java.util.Calendar.YEAR)}-${cal.get(java.util.Calendar.MONTH) + 1}-${cal.get(java.util.Calendar.DAY_OF_MONTH)}"
    }

    private fun saveLastUnlockedNow(incrementCount: Boolean = false) {
        val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val today = todayDateKey()
        val storedDate = prefs.getString(KEY_UNLOCK_DATE, "")
        var count = if (storedDate == today) prefs.getInt(KEY_UNLOCK_COUNT, 0) else 0
        if (incrementCount) {
            count += 1
        }
        prefs.edit()
            .putLong(KEY_LAST_UNLOCKED, System.currentTimeMillis())
            .putString(KEY_UNLOCK_DATE, today)
            .putInt(KEY_UNLOCK_COUNT, count)
            .apply()
    }

    private fun getUnlockCountToday(): Int {
        val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val today = todayDateKey()
        return if (prefs.getString(KEY_UNLOCK_DATE, "") == today) {
            prefs.getInt(KEY_UNLOCK_COUNT, 0)
        } else {
            0
        }
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
        telemetryChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, DEVICE_STATUS_CHANNEL)
        telemetryChannel?.setMethodCallHandler { call, result ->
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
                            val unlockCountToday = getUnlockCountToday()
                            val netType = readNetworkType()
                            val stepsToday = readHardwareStepsToday()

                            result.success(
                                mapOf(
                                    "level" to levelPercent,
                                    "isCharging" to isCharging,
                                    "isScreenOn" to isScreenOn,
                                    "isDeviceUnlocked" to isUnlocked,
                                    "lastUnlockedAtMs" to if (lastUnlockedMs > 0L) lastUnlockedMs else null,
                                    "unlockCountToday" to unlockCountToday,
                                    "networkType" to netType,
                                    "stepsToday" to stepsToday,
                                    "hasStepSensor" to (stepSensor != null)
                                )
                            )
                        } catch (e: Exception) {
                            result.error("TELEMETRY_ERROR", e.message, null)
                        }
                    }
                    "syncStepSensor" -> {
                        result.success(registerStepCounterListener())
                    }
                    "getHardwareStepsToday" -> {
                        try {
                            val stepsToday = readHardwareStepsToday()
                            result.success(
                                mapOf(
                                    "stepsToday" to stepsToday,
                                    "hasStepSensor" to (stepSensor != null),
                                    "permissionGranted" to hasActivityRecognitionPermission()
                                )
                            )
                        } catch (e: Exception) {
                            result.error("STEP_ERROR", e.message, null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
