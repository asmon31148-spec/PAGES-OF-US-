package com.pagesofus.app

import android.Manifest
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.PowerManager
import android.provider.Settings
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch

class MainActivity : AudioServiceActivity() {
    private val DEVICE_STATUS_CHANNEL = "com.pagesofus.app/device_status"
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main)

    private var screenReceiver: BroadcastReceiver? = null
    private var sensorManager: SensorManager? = null
    private var stepSensor: Sensor? = null
    private var stepListener: SensorEventListener? = null
    private var stepListenerRegistered = false
    private var telemetryChannel: MethodChannel? = null
    private var pendingHealthConnectResult: MethodChannel.Result? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        SanctuaryTelemetryStore.ensureDayAndArchiveIfNeeded(this)
        SanctuaryTelemetryService.start(this)
        registerScreenStateReceiver()
        if (SanctuaryTelemetryStore.isCurrentlyUnlocked(this)) {
            SanctuaryTelemetryStore.recordUserPresentUnlock(this, incrementCount = false)
        }
        registerStepCounterListener()
    }

    override fun onResume() {
        super.onResume()
        SanctuaryTelemetryStore.ensureDayAndArchiveIfNeeded(this)
        SanctuaryTelemetryService.start(this)
        if (SanctuaryTelemetryStore.isCurrentlyUnlocked(this)) {
            SanctuaryTelemetryStore.recordUserPresentUnlock(this, incrementCount = false)
        }
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
        scope.cancel()
        super.onDestroy()
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == HealthConnectHelper.REQ_HEALTH_CONNECT_PERMISSIONS) {
            val cb = pendingHealthConnectResult
            pendingHealthConnectResult = null
            if (cb != null) {
                scope.launch(Dispatchers.IO) {
                    val granted = HealthConnectHelper.hasAllPermissions(applicationContext)
                    launch(Dispatchers.Main) {
                        cb.success(granted)
                    }
                }
            }
        }
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
                        val prev = SanctuaryTelemetryStore.buildTelemetryMap(applicationContext)["stepsToday"] as? Int ?: 0
                        val updated = SanctuaryTelemetryStore.recordStepRawValue(applicationContext, event.values[0].toInt())
                        if (updated >= 0 && updated != prev) {
                            runOnUiThread {
                                try {
                                    telemetryChannel?.invokeMethod("onStepsChanged", mapOf("stepsToday" to updated))
                                } catch (_: Exception) {}
                            }
                        }
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

    private fun readHardwareStepsToday(): Int? {
        initStepSensor()
        if (stepSensor == null || !hasActivityRecognitionPermission()) {
            return null
        }
        registerStepCounterListener()
        return SanctuaryTelemetryStore.buildTelemetryMap(applicationContext)["stepsToday"] as? Int ?: 0
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
                val ctx = context ?: return
                val action = intent?.action ?: return
                when (action) {
                    Intent.ACTION_USER_PRESENT -> SanctuaryTelemetryStore.recordUserPresentUnlock(ctx, incrementCount = true)
                    Intent.ACTION_SCREEN_ON -> {
                        if (SanctuaryTelemetryStore.isCurrentlyUnlocked(ctx)) {
                            SanctuaryTelemetryStore.recordUserPresentUnlock(ctx, incrementCount = false)
                        }
                    }
                    Intent.ACTION_SCREEN_OFF -> SanctuaryTelemetryStore.recordScreenOffLock(ctx)
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

    private fun isIgnoringBatteryOptimizations(): Boolean {
        return try {
            val pm = getSystemService(Context.POWER_SERVICE) as? PowerManager ?: return true
            pm.isIgnoringBatteryOptimizations(packageName)
        } catch (_: Exception) {
            false
        }
    }

    private fun requestIgnoreBatteryOptimizations(): Boolean {
        return try {
            if (isIgnoringBatteryOptimizations()) return true
            val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                data = Uri.parse("package:$packageName")
            }
            startActivity(intent)
            true
        } catch (_: Exception) {
            try {
                startActivity(Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS))
                true
            } catch (_: Exception) {
                false
            }
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        telemetryChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, DEVICE_STATUS_CHANNEL)
        telemetryChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "getBatteryStatus" -> {
                    try {
                        val (levelPercent, isCharging) = SanctuaryTelemetryStore.readAndRecordBattery(applicationContext)
                        result.success(
                            mapOf(
                                "level" to levelPercent,
                                "batteryLevel" to levelPercent,
                                "isCharging" to isCharging
                            )
                        )
                    } catch (e: Exception) {
                        result.error("BATTERY_ERROR", e.message, null)
                    }
                }
                "getFullTelemetry" -> {
                    try {
                        registerStepCounterListener()
                        val map = SanctuaryTelemetryStore.buildTelemetryMap(applicationContext).toMutableMap()
                        map["hasStepSensor"] = (stepSensor != null)
                        map["isIgnoringBatteryOptimizations"] = isIgnoringBatteryOptimizations()
                        map["healthConnectStatus"] = HealthConnectHelper.sdkStatusString(applicationContext)
                        result.success(map)
                    } catch (e: Exception) {
                        result.error("TELEMETRY_ERROR", e.message, null)
                    }
                }
                "syncStepSensor" -> {
                    result.success(registerStepCounterListener())
                }
                "getHardwareStepsToday" -> {
                    try {
                        val steps = readHardwareStepsToday()
                        result.success(
                            mapOf(
                                "supported" to (stepSensor != null),
                                "permitted" to hasActivityRecognitionPermission(),
                                "stepsToday" to steps
                            )
                        )
                    } catch (e: Exception) {
                        result.success(
                            mapOf(
                                "supported" to false,
                                "permitted" to false,
                                "stepsToday" to null
                            )
                        )
                    }
                }
                "getHealthConnectToday" -> {
                    scope.launch(Dispatchers.IO) {
                        val res = HealthConnectHelper.readTodayStepsAndDistance(applicationContext)
                        launch(Dispatchers.Main) {
                            result.success(res)
                        }
                    }
                }
                "hasHealthConnectPermissions" -> {
                    scope.launch(Dispatchers.IO) {
                        val ok = HealthConnectHelper.hasAllPermissions(applicationContext)
                        launch(Dispatchers.Main) {
                            result.success(ok)
                        }
                    }
                }
                "requestHealthConnectPermissions" -> {
                    if (pendingHealthConnectResult != null) {
                        pendingHealthConnectResult?.success(false)
                    }
                    pendingHealthConnectResult = result
                    val launched = HealthConnectHelper.launchPermissionRequest(this)
                    if (!launched) {
                        pendingHealthConnectResult = null
                        result.success(false)
                    }
                }
                "isIgnoringBatteryOptimizations" -> {
                    result.success(isIgnoringBatteryOptimizations())
                }
                "requestIgnoreBatteryOptimizations" -> {
                    result.success(requestIgnoreBatteryOptimizations())
                }
                "configureTelemetryUpload" -> {
                    val supabaseUrl = call.argument<String>("supabaseUrl") ?: ""
                    val supabaseKey = call.argument<String>("supabaseKey") ?: ""
                    val accessToken = call.argument<String>("accessToken")
                    val spaceId = call.argument<String>("spaceId") ?: ""
                    val myUserId = call.argument<String>("myUserId") ?: ""
                    val myName = call.argument<String>("myName") ?: ""
                    SanctuaryTelemetryStore.configureCloudUpload(
                        applicationContext,
                        supabaseUrl,
                        supabaseKey,
                        accessToken,
                        spaceId,
                        myUserId,
                        myName
                    )
                    SanctuaryTelemetryService.start(applicationContext)
                    result.success(true)
                }
                "recordAppLifecycleForeground" -> {
                    val inFg = call.argument<Boolean>("inForeground") ?: false
                    SanctuaryTelemetryStore.recordAppForegroundChanged(applicationContext, inFg)
                    result.success(true)
                }
                "consumePendingDailySummary" -> {
                    result.success(SanctuaryTelemetryStore.consumePendingDailySummaryJson(applicationContext))
                }
                "getDebugTelemetrySnapshot" -> {
                    scope.launch(Dispatchers.IO) {
                        val hcPerm = HealthConnectHelper.hasAllPermissions(applicationContext)
                        val snap = SanctuaryTelemetryStore.getDebugSnapshot(applicationContext).toMutableMap()
                        snap["isIgnoringBatteryOptimizations"] = isIgnoringBatteryOptimizations()
                        snap["healthConnectStatus"] = HealthConnectHelper.sdkStatusString(applicationContext)
                        snap["healthConnectPermitted"] = hcPerm
                        snap["activityRecognitionPermitted"] = hasActivityRecognitionPermission()
                        snap["hasHardwareStepSensor"] = (stepSensor != null)
                        launch(Dispatchers.Main) {
                            result.success(snap)
                        }
                    }
                }
                "recordSyncError" -> {
                    val source = call.argument<String>("source") ?: "flutter"
                    val msg = call.argument<String>("message") ?: "Unknown error"
                    SanctuaryTelemetryStore.appendSyncError(applicationContext, source, msg)
                    result.success(true)
                }
                "startTelemetryService" -> {
                    SanctuaryTelemetryService.start(applicationContext)
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }
}
