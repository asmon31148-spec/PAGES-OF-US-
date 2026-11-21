package com.pagesofus.app

import android.Manifest
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.content.pm.PackageManager
import android.content.pm.ServiceInfo
import android.location.Location
import android.location.LocationListener
import android.location.LocationManager
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import androidx.core.content.ContextCompat
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch
import org.json.JSONArray
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Date
import java.util.Locale
import java.util.TimeZone

/**
 * Continuous Background Location Monitoring Foreground Service (Mode A).
 *
 * Runs as an independent Android Foreground Service with type "location"
 * to maintain trustworthy continuous background tracking even when the app
 * is minimized or swiped away from Android Recents.
 *
 * Employs adaptive sampling, stationary anchor hysteresis (45m threshold)
 * to reject indoor GPS drift, and batched uploads to Supabase.
 */
class SanctuaryLocationService : Service(), LocationListener {

    companion object {
        const val CHANNEL_ID = "sanctuary_location_channel"
        const val NOTIFICATION_ID = 4109
        const val PREFS_NAME = "pages_of_us_location"

        const val ACTION_START = "com.pagesofus.app.ACTION_START_LOCATION"
        const val ACTION_STOP = "com.pagesofus.app.ACTION_STOP_LOCATION"

        private const val KEY_IS_ACTIVE = "location_service_is_active"
        private const val KEY_TODAY_DATE = "location_today_date"
        private const val KEY_TODAY_DISTANCE_METERS = "today_distance_meters"
        private const val KEY_LAST_LAT = "last_recorded_lat"
        private const val KEY_LAST_LNG = "last_recorded_lng"
        private const val KEY_LAST_ACCURACY = "last_recorded_accuracy"
        private const val KEY_LAST_SPEED = "last_recorded_speed"
        private const val KEY_LAST_TIMESTAMP_MS = "last_recorded_timestamp_ms"
        private const val KEY_ANCHOR_LAT = "stationary_anchor_lat"
        private const val KEY_ANCHOR_LNG = "stationary_anchor_lng"
        private const val KEY_TRAIL_JSON = "today_trail_points_json"

        // Thresholds
        private const val MIN_STATIONARY_DISPLACEMENT_METERS = 45.0 // Reject indoor GPS jitter
        private const val DUPLICATE_COORDINATE_METERS = 4.0
        private const val MAX_ACCEPTABLE_ACCURACY_METERS = 65.0
        private const val MIN_UPLOAD_INTERVAL_MS = 60_000L
        private const val MAX_SAVED_TRAIL_POINTS = 500

        fun start(context: Context) {
            val appCtx = context.applicationContext
            appCtx.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                .edit().putBoolean(KEY_IS_ACTIVE, true).apply()
            val intent = Intent(appCtx, SanctuaryLocationService::class.java).apply {
                action = ACTION_START
            }
            try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    appCtx.startForegroundService(intent)
                } else {
                    appCtx.startService(intent)
                }
            } catch (_: Exception) {}
        }

        fun stop(context: Context) {
            val appCtx = context.applicationContext
            appCtx.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                .edit().putBoolean(KEY_IS_ACTIVE, false).apply()
            val intent = Intent(appCtx, SanctuaryLocationService::class.java).apply {
                action = ACTION_STOP
            }
            try {
                appCtx.startService(intent)
            } catch (_: Exception) {}
        }

        fun isLocationServiceActive(context: Context): Boolean {
            return context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                .getBoolean(KEY_IS_ACTIVE, false)
        }
    }

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
    private val mainHandler = Handler(Looper.getMainLooper())
    private var locationManager: LocationManager? = null

    private var lastUploadAtMs = 0L
    private var isGpsRegistered = false
    private var isNetworkRegistered = false

    private val periodicSyncRunnable = object : Runnable {
        override fun run() {
            flushLatestLocationToCloud(force = false)
            mainHandler.postDelayed(this, MIN_UPLOAD_INTERVAL_MS)
        }
    }

    override fun onCreate() {
        super.onCreate()
        ensureNotificationChannel()
        startForegroundNotification()
        locationManager = getSystemService(Context.LOCATION_SERVICE) as? LocationManager
        registerLocationListeners()
        mainHandler.postDelayed(periodicSyncRunnable, MIN_UPLOAD_INTERVAL_MS)
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP) {
            stopLocationUpdates()
            mainHandler.removeCallbacks(periodicSyncRunnable)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                stopForeground(STOP_FOREGROUND_REMOVE)
            } else {
                @Suppress("DEPRECATION")
                stopForeground(true)
            }
            stopSelf()
            return START_NOT_STICKY
        }

        startForegroundNotification()
        registerLocationListeners()
        return START_STICKY
    }

    override fun onDestroy() {
        stopLocationUpdates()
        mainHandler.removeCallbacks(periodicSyncRunnable)
        scope.cancel()
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    // ── LocationListener Implementation ────────────────────────────────────────

    override fun onLocationChanged(location: Location) {
        processNewLocation(location)
    }

    @Deprecated("Deprecated in Java")
    override fun onStatusChanged(provider: String?, status: Int, extras: Bundle?) {}

    override fun onProviderEnabled(provider: String) {
        registerLocationListeners()
    }

    override fun onProviderDisabled(provider: String) {
        // Continue with whatever provider remains
    }

    // ── Foreground Notification ────────────────────────────────────────────────

    private fun ensureNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val mgr = getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager ?: return
            if (mgr.getNotificationChannel(CHANNEL_ID) == null) {
                val channel = NotificationChannel(
                    CHANNEL_ID,
                    "Pages of Us Location Sharing",
                    NotificationManager.IMPORTANCE_LOW
                ).apply {
                    description = "Shares your authentic live location and journey with your partner."
                    setShowBadge(false)
                    setSound(null, null)
                    enableVibration(false)
                }
                mgr.createNotificationChannel(channel)
            }
        }
    }

    private fun startForegroundNotification() {
        val launchIntent = packageManager.getLaunchIntentForPackage(packageName)
        val pendingFlags = PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        val pendingIntent = if (launchIntent != null) {
            PendingIntent.getActivity(this, 0, launchIntent, pendingFlags)
        } else null

        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }

        builder.setContentTitle("Pages of Us • Location sharing active")
            .setContentText("Sharing live journey quietly with your partner")
            .setSmallIcon(applicationInfo.icon)
            .setOngoing(true)
            .setOnlyAlertOnce(true)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            builder.setForegroundServiceBehavior(Notification.FOREGROUND_SERVICE_DEFERRED)
        }
        if (pendingIntent != null) {
            builder.setContentIntent(pendingIntent)
        }

        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                startForeground(
                    NOTIFICATION_ID,
                    builder.build(),
                    ServiceInfo.FOREGROUND_SERVICE_TYPE_LOCATION
                )
            } else {
                startForeground(NOTIFICATION_ID, builder.build())
            }
        } catch (_: Exception) {
            try {
                startForeground(NOTIFICATION_ID, builder.build())
            } catch (_: Exception) {}
        }
    }

    // ── Registration & Adaptive Intervals ──────────────────────────────────────

    private fun hasLocationPermission(): Boolean {
        val fine = ContextCompat.checkSelfPermission(this, Manifest.permission.ACCESS_FINE_LOCATION)
        val coarse = ContextCompat.checkSelfPermission(this, Manifest.permission.ACCESS_COARSE_LOCATION)
        return fine == PackageManager.PERMISSION_GRANTED || coarse == PackageManager.PERMISSION_GRANTED
    }

    private fun registerLocationListeners() {
        val lm = locationManager ?: return
        if (!hasLocationPermission()) return

        try {
            // Adaptive sampling: 15 seconds, 10 meters distance filter
            if (!isGpsRegistered && lm.isProviderEnabled(LocationManager.GPS_PROVIDER)) {
                lm.requestLocationUpdates(
                    LocationManager.GPS_PROVIDER,
                    15_000L,
                    10.0f,
                    this,
                    Looper.getMainLooper()
                )
                isGpsRegistered = true
            }
        } catch (_: SecurityException) {}

        try {
            // Network provider fallback
            if (!isNetworkRegistered && lm.isProviderEnabled(LocationManager.NETWORK_PROVIDER)) {
                lm.requestLocationUpdates(
                    LocationManager.NETWORK_PROVIDER,
                    30_000L,
                    15.0f,
                    this,
                    Looper.getMainLooper()
                )
                isNetworkRegistered = true
            }
        } catch (_: SecurityException) {}
    }

    private fun stopLocationUpdates() {
        val lm = locationManager ?: return
        try {
            lm.removeUpdates(this)
        } catch (_: Exception) {}
        isGpsRegistered = false
        isNetworkRegistered = false
    }

    // ── Location Processing & Stationary Hysteresis ────────────────────────────

    private fun processNewLocation(location: Location) {
        val lat = location.latitude
        val lng = location.longitude
        val accuracy = location.accuracy.toDouble()
        val speed = if (location.hasSpeed()) location.speed.toDouble() else 0.0
        val nowMs = System.currentTimeMillis()

        // 1. Accuracy Filter
        if (accuracy > MAX_ACCEPTABLE_ACCURACY_METERS) {
            // Too noisy, reject to avoid fake jumps
            return
        }

        val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val todayKey = todayDateKey(nowMs)
        val savedDate = prefs.getString(KEY_TODAY_DATE, "")

        // Midnight Rollover Check: Reset distance and trail at 00:00
        val isNewDay = savedDate != todayKey
        var todayDistanceMeters = if (isNewDay) 0.0 else prefs.getFloat(KEY_TODAY_DISTANCE_METERS, 0.0f).toDouble()

        val lastLat = prefs.getFloat(KEY_LAST_LAT, 0.0f).toDouble()
        val lastLng = prefs.getFloat(KEY_LAST_LNG, 0.0f).toDouble()
        var anchorLat = prefs.getFloat(KEY_ANCHOR_LAT, 0.0f).toDouble()
        var anchorLng = prefs.getFloat(KEY_ANCHOR_LNG, 0.0f).toDouble()

        var displacement = 0.0
        if (lastLat != 0.0 && lastLng != 0.0 && !isNewDay) {
            val distResults = FloatArray(1)
            Location.distanceBetween(lastLat, lastLng, lat, lng, distResults)
            displacement = distResults[0].toDouble()

            // 2. Duplicate Coordinate Check
            if (displacement < DUPLICATE_COORDINATE_METERS) {
                return
            }
        }

        // 3. Stationary Anchor Hysteresis (Room-Lock Drift Filter)
        if (anchorLat == 0.0 || anchorLng == 0.0 || isNewDay) {
            anchorLat = lat
            anchorLng = lng
        }

        val anchorDistResults = FloatArray(1)
        Location.distanceBetween(anchorLat, anchorLng, lat, lng, anchorDistResults)
        val distFromAnchor = anchorDistResults[0].toDouble()

        var isGenuineMovement = false
        if (distFromAnchor >= MIN_STATIONARY_DISPLACEMENT_METERS || speed > 1.2) {
            // Moved outside anchor circle or moving with genuine speed
            isGenuineMovement = true
            anchorLat = lat
            anchorLng = lng
            if (displacement > 0.0 && displacement < 2000.0) { // Reject teleport anomalies > 2km in 15s
                todayDistanceMeters += displacement
            }
        }

        // 4. Update Trail JSON
        val trailRaw = if (isNewDay) "[]" else (prefs.getString(KEY_TRAIL_JSON, "[]") ?: "[]")
        val trailArray = try { JSONArray(trailRaw) } catch (_: Exception) { JSONArray() }

        val newPoint = JSONObject().apply {
            put("lat", lat)
            put("lng", lng)
            put("ts", nowMs)
            put("acc", accuracy)
            put("sp", speed)
        }
        trailArray.put(newPoint)

        // Cap to latest 500 points
        val cappedArray = if (trailArray.length() > MAX_SAVED_TRAIL_POINTS) {
            val sub = JSONArray()
            val startIdx = trailArray.length() - MAX_SAVED_TRAIL_POINTS
            for (i in startIdx until trailArray.length()) {
                sub.put(trailArray.get(i))
            }
            sub
        } else {
            trailArray
        }

        // Persist to local SharedPreferences
        prefs.edit()
            .putString(KEY_TODAY_DATE, todayKey)
            .putFloat(KEY_TODAY_DISTANCE_METERS, todayDistanceMeters.toFloat())
            .putFloat(KEY_LAST_LAT, lat.toFloat())
            .putFloat(KEY_LAST_LNG, lng.toFloat())
            .putFloat(KEY_LAST_ACCURACY, accuracy.toFloat())
            .putFloat(KEY_LAST_SPEED, speed.toFloat())
            .putLong(KEY_LAST_TIMESTAMP_MS, nowMs)
            .putFloat(KEY_ANCHOR_LAT, anchorLat.toFloat())
            .putFloat(KEY_ANCHOR_LNG, anchorLng.toFloat())
            .putString(KEY_TRAIL_JSON, cappedArray.toString())
            .apply()

        // 5. Cloud Upload Check
        val timeSinceUpload = nowMs - lastUploadAtMs
        if (isGenuineMovement || timeSinceUpload >= MIN_UPLOAD_INTERVAL_MS) {
            flushLatestLocationToCloud(force = false)
        }
    }

    // ── Batched Supabase Upload ────────────────────────────────────────────────

    private fun flushLatestLocationToCloud(force: Boolean) {
        val nowMs = System.currentTimeMillis()
        if (!force && (nowMs - lastUploadAtMs < 30_000L)) return

        val cfg = SanctuaryTelemetryStore.getSupabaseConfig(this)
        val urlBase = cfg["urlBase"] ?: ""
        val anonKey = cfg["anonKey"] ?: ""
        val accessToken = cfg["accessToken"] ?: ""
        val spaceId = cfg["spaceId"] ?: ""
        val userId = cfg["userId"] ?: ""
        val myName = cfg["myName"] ?: ""

        if (urlBase.isEmpty() || anonKey.isEmpty() || spaceId.isEmpty() || userId.isEmpty()) {
            return
        }

        val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val lat = prefs.getFloat(KEY_LAST_LAT, 0.0f).toDouble()
        val lng = prefs.getFloat(KEY_LAST_LNG, 0.0f).toDouble()
        if (lat == 0.0 && lng == 0.0) return

        val accuracy = prefs.getFloat(KEY_LAST_ACCURACY, 0.0f).toDouble()
        val speed = prefs.getFloat(KEY_LAST_SPEED, 0.0f).toDouble()
        val distanceKm = prefs.getFloat(KEY_TODAY_DISTANCE_METERS, 0.0f).toDouble() / 1000.0
        val trailRaw = prefs.getString(KEY_TRAIL_JSON, "[]") ?: "[]"
        val trailPoints = try { JSONArray(trailRaw) } catch (_: Exception) { JSONArray() }

        val bearer = if (accessToken.isNotEmpty()) accessToken else anonKey
        val isoFormatter = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'", Locale.US).apply {
            timeZone = TimeZone.getTimeZone("UTC")
        }
        val isoNow = isoFormatter.format(Date(nowMs))

        scope.launch {
            try {
                // 1. Upload journey_today_${spaceId}_${userId}
                val journeyPayload = JSONObject().apply {
                    put("id", "journey_today_${spaceId}_$userId")
                    put("content", JSONObject().apply {
                        put("userId", userId)
                        put("spaceId", spaceId)
                        put("distanceKm", distanceKm)
                        put("points", trailPoints)
                        put("updated_at", isoNow)
                    })
                    put("updated_at", isoNow)
                }
                SanctuaryTelemetryStore.postSupabaseUpsert(urlBase, anonKey, bearer, journeyPayload)

                // 2. Update location_${spaceId}
                val userLocationJson = JSONObject().apply {
                    put("userId", userId)
                    put("nickname", myName)
                    put("lat", lat)
                    put("lng", lng)
                    put("accuracy", accuracy)
                    put("speedMps", speed)
                    put("isSharingEnabled", true)
                    put("journeyKmToday", distanceKm)
                    put("updatedAt", isoNow)
                }

                val locationRowPayload = JSONObject().apply {
                    put("id", "location_$spaceId")
                    put("content", JSONObject().apply {
                        put(userId, userLocationJson)
                    })
                    put("updated_at", isoNow)
                }
                SanctuaryTelemetryStore.postSupabaseUpsert(urlBase, anonKey, bearer, locationRowPayload)

                lastUploadAtMs = nowMs
            } catch (e: Exception) {
                SanctuaryTelemetryStore.appendSyncError(this@SanctuaryLocationService, "bg_location_upload", e.message ?: "Network error")
            }
        }
    }

    private fun todayDateKey(nowMs: Long = System.currentTimeMillis()): String {
        val cal = Calendar.getInstance()
        cal.timeInMillis = nowMs
        val y = cal.get(Calendar.YEAR)
        val m = cal.get(Calendar.MONTH) + 1
        val d = cal.get(Calendar.DAY_OF_MONTH)
        return String.format(Locale.US, "%04d-%02d-%02d", y, m, d)
    }
}
