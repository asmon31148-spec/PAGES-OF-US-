package com.pagesofus.app

import android.Manifest
import android.app.NotificationManager
import android.app.Service
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
import android.net.Network
import android.net.NetworkCapabilities
import android.net.NetworkRequest
import android.os.BatteryManager
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch

class SanctuaryTelemetryService : Service() {
    companion object {
        private const val CHANNEL_ID = "sanctuary_telemetry_quiet"
        private const val NOTIFICATION_ID = 4108
        private const val HEARTBEAT_INTERVAL_MS = 120_000L

        fun start(context: Context) {
            val appCtx = context.applicationContext
            clearLegacyForegroundNotification(appCtx)
            val intent = Intent(appCtx, SanctuaryTelemetryService::class.java)
            try {
                // Run as a regular silent service (no foreground notification)
                appCtx.startService(intent)
            } catch (_: Exception) {
                // Background start restrictions on Android 8+ may block startService from boot receiver;
                // MainActivity.onResume / Dart sync will start it silently when app is active.
            }
        }

        private fun clearLegacyForegroundNotification(context: Context) {
            try {
                val mgr = context.getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager ?: return
                mgr.cancel(NOTIFICATION_ID)
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    try { mgr.deleteNotificationChannel("sanctuary_telemetry_sync") } catch (_: Exception) {}
                    try { mgr.deleteNotificationChannel(CHANNEL_ID) } catch (_: Exception) {}
                }
            } catch (_: Exception) {}
        }
    }

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
    private val mainHandler = Handler(Looper.getMainLooper())

    private var stateReceiver: BroadcastReceiver? = null
    private var networkCallback: ConnectivityManager.NetworkCallback? = null
    private var sensorManager: SensorManager? = null
    private var stepListener: SensorEventListener? = null
    private var stepRegistered = false
    private var lastUploadedBattery = -1
    private var lastUploadAtMs = 0L

    private val heartbeatRunnable = object : Runnable {
        override fun run() {
            scheduleBackgroundSync(force = true)
            mainHandler.postDelayed(this, HEARTBEAT_INTERVAL_MS)
        }
    }

    override fun onCreate() {
        super.onCreate()
        clearLegacyForegroundNotification(this)
        SanctuaryTelemetryStore.ensureDayAndArchiveIfNeeded(this)
        if (SanctuaryTelemetryStore.isCurrentlyUnlocked(this)) {
            SanctuaryTelemetryStore.recordUserPresentUnlock(this, incrementCount = false)
        }
        SanctuaryTelemetryStore.readAndRecordBattery(this)
        SanctuaryTelemetryStore.readAndRecordNetwork(this)
        registerReceivers()
        registerNetworkObserver()
        registerStepSensor()
        mainHandler.removeCallbacks(heartbeatRunnable)
        mainHandler.postDelayed(heartbeatRunnable, HEARTBEAT_INTERVAL_MS)
        scheduleBackgroundSync(force = true)
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        clearLegacyForegroundNotification(this)
        registerStepSensor()
        return START_STICKY
    }

    override fun onDestroy() {
        mainHandler.removeCallbacks(heartbeatRunnable)
        try {
            stateReceiver?.let { unregisterReceiver(it) }
        } catch (_: Exception) {}
        stateReceiver = null
        try {
            val cm = getSystemService(Context.CONNECTIVITY_SERVICE) as? ConnectivityManager
            networkCallback?.let { cm?.unregisterNetworkCallback(it) }
        } catch (_: Exception) {}
        networkCallback = null
        try {
            stepListener?.let { sensorManager?.unregisterListener(it) }
        } catch (_: Exception) {}
        stepRegistered = false
        scope.cancel()
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun registerReceivers() {
        if (stateReceiver != null) return
        val filter = IntentFilter().apply {
            addAction(Intent.ACTION_USER_PRESENT)
            addAction(Intent.ACTION_SCREEN_ON)
            addAction(Intent.ACTION_SCREEN_OFF)
            addAction(Intent.ACTION_BATTERY_CHANGED)
            addAction(Intent.ACTION_DATE_CHANGED)
            addAction(Intent.ACTION_TIME_CHANGED)
            addAction(Intent.ACTION_TIMEZONE_CHANGED)
        }
        stateReceiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context?, intent: Intent?) {
                val ctx = context ?: return
                val action = intent?.action ?: return
                when (action) {
                    Intent.ACTION_USER_PRESENT -> {
                        SanctuaryTelemetryStore.recordUserPresentUnlock(ctx, incrementCount = true)
                        scheduleBackgroundSync(force = true)
                    }
                    Intent.ACTION_SCREEN_ON -> {
                        if (SanctuaryTelemetryStore.isCurrentlyUnlocked(ctx)) {
                            SanctuaryTelemetryStore.recordUserPresentUnlock(ctx, incrementCount = false)
                        }
                    }
                    Intent.ACTION_SCREEN_OFF -> {
                        SanctuaryTelemetryStore.recordScreenOffLock(ctx)
                        scheduleBackgroundSync(force = true)
                    }
                    Intent.ACTION_BATTERY_CHANGED -> {
                        val (lvl, _) = SanctuaryTelemetryStore.readAndRecordBattery(ctx, intent)
                        if (lvl >= 0 && lvl != lastUploadedBattery) {
                            lastUploadedBattery = lvl
                            scheduleBackgroundSync(force = false)
                        }
                    }
                    Intent.ACTION_DATE_CHANGED,
                    Intent.ACTION_TIME_CHANGED,
                    Intent.ACTION_TIMEZONE_CHANGED -> {
                        SanctuaryTelemetryStore.ensureDayAndArchiveIfNeeded(ctx)
                        scheduleBackgroundSync(force = true)
                    }
                }
            }
        }
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                registerReceiver(stateReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
            } else {
                registerReceiver(stateReceiver, filter)
            }
        } catch (_: Exception) {}
    }

    private fun registerNetworkObserver() {
        try {
            val cm = getSystemService(Context.CONNECTIVITY_SERVICE) as? ConnectivityManager ?: return
            val req = NetworkRequest.Builder()
                .addCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
                .build()
            val cb = object : ConnectivityManager.NetworkCallback() {
                override fun onAvailable(network: Network) {
                    SanctuaryTelemetryStore.readAndRecordNetwork(applicationContext)
                    scheduleBackgroundSync(force = false)
                }

                override fun onLost(network: Network) {
                    SanctuaryTelemetryStore.readAndRecordNetwork(applicationContext)
                }

                override fun onCapabilitiesChanged(network: Network, networkCapabilities: NetworkCapabilities) {
                    SanctuaryTelemetryStore.readAndRecordNetwork(applicationContext)
                }
            }
            cm.registerNetworkCallback(req, cb)
            networkCallback = cb
        } catch (_: Exception) {}
    }

    private fun registerStepSensor() {
        if (stepRegistered) return
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q &&
            checkSelfPermission(Manifest.permission.ACTIVITY_RECOGNITION) != PackageManager.PERMISSION_GRANTED
        ) {
            return
        }
        try {
            val sm = getSystemService(Context.SENSOR_SERVICE) as? SensorManager ?: return
            sensorManager = sm
            val sensor = sm.getDefaultSensor(Sensor.TYPE_STEP_COUNTER) ?: return
            val listener = object : SensorEventListener {
                override fun onSensorChanged(event: SensorEvent?) {
                    if (event?.sensor?.type == Sensor.TYPE_STEP_COUNTER && event.values.isNotEmpty()) {
                        SanctuaryTelemetryStore.recordStepRawValue(applicationContext, event.values[0].toInt())
                    }
                }

                override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {}
            }
            stepListener = listener
            stepRegistered = sm.registerListener(listener, sensor, SensorManager.SENSOR_DELAY_NORMAL)
        } catch (_: Exception) {}
    }

    private fun scheduleBackgroundSync(force: Boolean) {
        val now = System.currentTimeMillis()
        if (!force && (now - lastUploadAtMs) < 15_000L) return
        lastUploadAtMs = now
        scope.launch {
            if (HealthConnectHelper.hasAllPermissions(applicationContext)) {
                HealthConnectHelper.readTodayStepsAndDistance(applicationContext)
            }
            SanctuaryTelemetryStore.uploadSnapshotAndPendingSummaries(applicationContext)
        }
    }
}
