package com.pagesofus.app

import android.app.KeyguardManager
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.os.BatteryManager
import android.os.Build
import android.os.PowerManager
import org.json.JSONArray
import org.json.JSONObject
import java.io.OutputStreamWriter
import java.net.HttpURLConnection
import java.net.URL
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Date
import java.util.Locale
import java.util.TimeZone

object SanctuaryTelemetryStore {
    const val PREFS_NAME = "pages_of_us_telemetry"

    private const val KEY_ACTIVE_DATE = "active_date_key"
    private const val KEY_TIMEZONE_OFFSET_MIN = "timezone_offset_minutes"

    // Unlock / lock + Screen time
    private const val KEY_LAST_UNLOCKED = "last_unlocked_at_ms"
    private const val KEY_FIRST_UNLOCKED = "first_unlocked_at_ms"
    private const val KEY_LAST_LOCKED = "last_locked_at_ms"
    private const val KEY_UNLOCK_COUNT = "unlock_count_today"
    private const val KEY_LOCK_COUNT = "lock_count_today"
    private const val KEY_SCREEN_EVENTS_JSON = "screen_events_today_json"
    private const val KEY_IS_SCREEN_UNLOCKED = "is_screen_unlocked"
    private const val KEY_UNLOCK_SESSION_START_MS = "unlock_session_start_ms"
    private const val KEY_SCREEN_TIME_SECONDS = "screen_time_seconds_today"

    // App foreground time (separate from walking time & screen time)
    private const val KEY_APP_IN_FOREGROUND = "app_in_foreground"
    private const val KEY_APP_SESSION_START_MS = "app_session_start_ms"
    private const val KEY_APP_TIME_SECONDS = "app_time_seconds_today"

    // Steps & Walking
    private const val KEY_STEP_DATE = "step_count_date"
    private const val KEY_STEP_LAST_RAW = "step_last_raw"
    private const val KEY_STEP_TODAY = "step_today_total"
    private const val KEY_STEP_HAS_BASELINE = "step_has_baseline"
    private const val KEY_STEPS_UPDATED_AT = "steps_updated_at_ms"
    private const val KEY_LAST_STEP_BURST_MS = "last_step_burst_ms"
    private const val KEY_WALKING_TIME_SECONDS = "walking_time_seconds_today"
    private const val KEY_HC_STEPS_TODAY = "hc_steps_today"
    private const val KEY_HC_DISTANCE_KM_TODAY = "hc_distance_km_today"
    private const val KEY_HC_UPDATED_AT = "hc_updated_at_ms"
    private const val KEY_STEP_SOURCE = "step_source"
    private const val KEY_MOVEMENT_ACTIVITY = "movement_activity"

    // Battery & Network with independent updated timestamps
    private const val KEY_BATTERY_LEVEL = "battery_level_cached"
    private const val KEY_BATTERY_CHARGING = "battery_charging_cached"
    private const val KEY_BATTERY_UPDATED_AT = "battery_updated_at_ms"
    private const val KEY_NETWORK_TYPE = "network_type_cached"
    private const val KEY_NETWORK_UPDATED_AT = "network_updated_at_ms"

    // Daily rollover archives
    private const val KEY_COMPLETED_SUMMARY_JSON = "completed_daily_summary_json"
    private const val KEY_PENDING_SUMMARIES_JSON = "pending_daily_summaries_json"

    // Cloud upload config & error log
    private const val KEY_CFG_SUPABASE_URL = "cfg_supabase_url"
    private const val KEY_CFG_SUPABASE_KEY = "cfg_supabase_key"
    private const val KEY_CFG_ACCESS_TOKEN = "cfg_access_token"
    private const val KEY_CFG_SPACE_ID = "cfg_space_id"
    private const val KEY_CFG_MY_USER_ID = "cfg_my_user_id"
    private const val KEY_CFG_MY_NAME = "cfg_my_name"
    private const val KEY_LAST_CLOUD_SYNC_AT = "last_cloud_sync_at_ms"
    private const val KEY_SYNC_ERROR_LOG_JSON = "sync_error_log_json"

    private val lock = Any()

    fun todayDateKey(nowMs: Long = System.currentTimeMillis()): String {
        val cal = Calendar.getInstance()
        cal.timeInMillis = nowMs
        val y = cal.get(Calendar.YEAR)
        val m = cal.get(Calendar.MONTH) + 1
        val d = cal.get(Calendar.DAY_OF_MONTH)
        return String.format(Locale.US, "%04d-%02d-%02d", y, m, d)
    }

    fun timezoneOffsetMinutes(nowMs: Long = System.currentTimeMillis()): Int {
        return TimeZone.getDefault().getOffset(nowMs) / 60000
    }

    private fun prefs(context: Context) =
        context.applicationContext.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

    fun ensureDayAndArchiveIfNeeded(context: Context, nowMs: Long = System.currentTimeMillis()) {
        synchronized(lock) {
            val p = prefs(context)
            val today = todayDateKey(nowMs)
            val stored = p.getString(KEY_ACTIVE_DATE, "") ?: ""
            if (stored.isEmpty()) {
                p.edit()
                    .putString(KEY_ACTIVE_DATE, today)
                    .putInt(KEY_TIMEZONE_OFFSET_MIN, timezoneOffsetMinutes(nowMs))
                    .apply()
                return
            }
            if (stored == today) return

            // Close ongoing sessions cleanly right up to Archive moment
            val finalizedScreenSec = computeEffectiveScreenTimeLocked(p, nowMs)
            val finalizedAppSec = computeEffectiveAppTimeLocked(p, nowMs)
            val effectiveSteps = computeEffectiveStepsLocked(p)
            val hcDistKm = p.getFloat(KEY_HC_DISTANCE_KM_TODAY, 0f).toDouble()

            val summary = JSONObject().apply {
                put("dateKey", stored)
                put("steps", effectiveSteps)
                put("distanceKm", hcDistKm)
                put("walkingTimeSeconds", p.getInt(KEY_WALKING_TIME_SECONDS, 0))
                put("screenTimeSeconds", finalizedScreenSec)
                put("appTimeSeconds", finalizedAppSec)
                put("unlockCount", p.getInt(KEY_UNLOCK_COUNT, 0))
                put("lockCount", p.getInt(KEY_LOCK_COUNT, 0))
                put("firstUnlockedAtMs", p.getLong(KEY_FIRST_UNLOCKED, 0L))
                put("lastUnlockedAtMs", p.getLong(KEY_LAST_UNLOCKED, 0L))
                put("lastLockedAtMs", p.getLong(KEY_LAST_LOCKED, 0L))
                put("timeZoneOffsetMinutes", p.getInt(KEY_TIMEZONE_OFFSET_MIN, timezoneOffsetMinutes(nowMs)))
                put("closedAtMs", nowMs)
            }

            val pendingRaw = p.getString(KEY_PENDING_SUMMARIES_JSON, "[]") ?: "[]"
            val pendingArr = try { JSONArray(pendingRaw) } catch (_: Exception) { JSONArray() }
            pendingArr.put(summary)
            val trimmedPending = JSONArray()
            val startIdx = kotlin.math.max(0, pendingArr.length() - 14)
            for (i in startIdx until pendingArr.length()) {
                trimmedPending.put(pendingArr.get(i))
            }

            val stillUnlocked = isCurrentlyUnlocked(context)
            val stillForeground = p.getBoolean(KEY_APP_IN_FOREGROUND, false)

            p.edit()
                .putString(KEY_COMPLETED_SUMMARY_JSON, summary.toString())
                .putString(KEY_PENDING_SUMMARIES_JSON, trimmedPending.toString())
                .putString(KEY_ACTIVE_DATE, today)
                .putInt(KEY_TIMEZONE_OFFSET_MIN, timezoneOffsetMinutes(nowMs))
                // Reset unlock/lock counters for new day while keeping open session seamless
                .putInt(KEY_UNLOCK_COUNT, 0)
                .putInt(KEY_LOCK_COUNT, 0)
                .putLong(KEY_FIRST_UNLOCKED, if (stillUnlocked) nowMs else 0L)
                .putLong(KEY_LAST_UNLOCKED, if (stillUnlocked) nowMs else 0L)
                .putLong(KEY_LAST_LOCKED, 0L)
                .putString(KEY_SCREEN_EVENTS_JSON, "[]")
                .putInt(KEY_SCREEN_TIME_SECONDS, 0)
                .putBoolean(KEY_IS_SCREEN_UNLOCKED, stillUnlocked)
                .putLong(KEY_UNLOCK_SESSION_START_MS, if (stillUnlocked) nowMs else 0L)
                // Reset app time keeping open foreground session
                .putInt(KEY_APP_TIME_SECONDS, 0)
                .putLong(KEY_APP_SESSION_START_MS, if (stillForeground) nowMs else 0L)
                // Reset steps keeping hardware raw baseline at lastRaw
                .putString(KEY_STEP_DATE, today)
                .putInt(KEY_STEP_TODAY, 0)
                .putInt(KEY_WALKING_TIME_SECONDS, 0)
                .putInt(KEY_HC_STEPS_TODAY, -1)
                .putFloat(KEY_HC_DISTANCE_KM_TODAY, 0f)
                .putString(KEY_MOVEMENT_ACTIVITY, "stationary")
                .apply()
        }
    }

    fun isCurrentlyUnlocked(context: Context): Boolean {
        return try {
            val pm = context.getSystemService(Context.POWER_SERVICE) as? PowerManager
            val km = context.getSystemService(Context.KEYGUARD_SERVICE) as? KeyguardManager
            (pm?.isInteractive == true) && (km?.isKeyguardLocked == false)
        } catch (_: Exception) {
            false
        }
    }

    fun recordUserPresentUnlock(context: Context, incrementCount: Boolean, nowMs: Long = System.currentTimeMillis()) {
        ensureDayAndArchiveIfNeeded(context, nowMs)
        synchronized(lock) {
            val p = prefs(context)
            val wasUnlocked = p.getBoolean(KEY_IS_SCREEN_UNLOCKED, false)
            var count = p.getInt(KEY_UNLOCK_COUNT, 0)
            var firstUnlocked = p.getLong(KEY_FIRST_UNLOCKED, 0L)
            val editor = p.edit()
                .putLong(KEY_LAST_UNLOCKED, nowMs)
                .putBoolean(KEY_IS_SCREEN_UNLOCKED, true)

            if (firstUnlocked <= 0L) {
                firstUnlocked = nowMs
                editor.putLong(KEY_FIRST_UNLOCKED, firstUnlocked)
            }

            if (!wasUnlocked || incrementCount) {
                if (incrementCount) {
                    count += 1
                    editor.putInt(KEY_UNLOCK_COUNT, count)
                }
                if (p.getLong(KEY_UNLOCK_SESSION_START_MS, 0L) <= 0L) {
                    editor.putLong(KEY_UNLOCK_SESSION_START_MS, nowMs)
                }
                appendScreenEventLocked(p, editor, "unlock", nowMs, 0)
            }
            editor.apply()
        }
    }

    fun recordScreenOffLock(context: Context, nowMs: Long = System.currentTimeMillis()) {
        ensureDayAndArchiveIfNeeded(context, nowMs)
        synchronized(lock) {
            val p = prefs(context)
            val wasUnlocked = p.getBoolean(KEY_IS_SCREEN_UNLOCKED, false)
            val startMs = p.getLong(KEY_UNLOCK_SESSION_START_MS, 0L)
            var screenTimeSec = p.getInt(KEY_SCREEN_TIME_SECONDS, 0)
            var sessionSec = 0
            if (wasUnlocked && startMs > 0L && nowMs > startMs) {
                // Guard against clock jump > 12h
                sessionSec = ((nowMs - startMs) / 1000L).toInt().coerceIn(0, 43200)
                screenTimeSec += sessionSec
            }

            val editor = p.edit()
                .putBoolean(KEY_IS_SCREEN_UNLOCKED, false)
                .putLong(KEY_UNLOCK_SESSION_START_MS, 0L)
                .putInt(KEY_SCREEN_TIME_SECONDS, screenTimeSec)
                .putLong(KEY_LAST_LOCKED, nowMs)

            if (wasUnlocked || p.getInt(KEY_UNLOCK_COUNT, 0) > p.getInt(KEY_LOCK_COUNT, 0)) {
                val nextLockCount = p.getInt(KEY_LOCK_COUNT, 0) + 1
                editor.putInt(KEY_LOCK_COUNT, nextLockCount)
                appendScreenEventLocked(p, editor, "lock", nowMs, sessionSec)
            }
            editor.apply()
        }
    }

    private fun appendScreenEventLocked(
        p: android.content.SharedPreferences,
        editor: android.content.SharedPreferences.Editor,
        type: String,
        tsMs: Long,
        durationSec: Int
    ) {
        val raw = p.getString(KEY_SCREEN_EVENTS_JSON, "[]") ?: "[]"
        val arr = try { JSONArray(raw) } catch (_: Exception) { JSONArray() }
        // Avoid duplicate identical event within 1500ms
        if (arr.length() > 0) {
            val last = arr.optJSONObject(arr.length() - 1)
            if (last != null && last.optString("type") == type && kotlin.math.abs(tsMs - last.optLong("tsMs")) < 1500L) {
                return
            }
        }
        val item = JSONObject().apply {
            put("type", type)
            put("tsMs", tsMs)
            if (durationSec > 0) put("durationSec", durationSec)
        }
        arr.put(item)
        val trimmed = JSONArray()
        val startIdx = kotlin.math.max(0, arr.length() - 60)
        for (i in startIdx until arr.length()) {
            trimmed.put(arr.get(i))
        }
        editor.putString(KEY_SCREEN_EVENTS_JSON, trimmed.toString())
    }

    fun recordAppForegroundChanged(context: Context, inForeground: Boolean, nowMs: Long = System.currentTimeMillis()) {
        ensureDayAndArchiveIfNeeded(context, nowMs)
        synchronized(lock) {
            val p = prefs(context)
            val prevInFg = p.getBoolean(KEY_APP_IN_FOREGROUND, false)
            val startMs = p.getLong(KEY_APP_SESSION_START_MS, 0L)
            var totalAppSec = p.getInt(KEY_APP_TIME_SECONDS, 0)
            if (prevInFg && !inForeground && startMs > 0L && nowMs > startMs) {
                val deltaSec = ((nowMs - startMs) / 1000L).toInt().coerceIn(0, 43200)
                totalAppSec += deltaSec
            }
            val editor = p.edit()
                .putBoolean(KEY_APP_IN_FOREGROUND, inForeground)
                .putInt(KEY_APP_TIME_SECONDS, totalAppSec)
            if (inForeground && (!prevInFg || startMs <= 0L)) {
                editor.putLong(KEY_APP_SESSION_START_MS, nowMs)
            } else if (!inForeground) {
                editor.putLong(KEY_APP_SESSION_START_MS, 0L)
            }
            editor.apply()
        }
    }

    fun recordStepRawValue(context: Context, raw: Int, nowMs: Long = System.currentTimeMillis()): Int {
        if (raw < 0) return -1
        ensureDayAndArchiveIfNeeded(context, nowMs)
        synchronized(lock) {
            val p = prefs(context)
            val today = todayDateKey(nowMs)
            val storedDate = p.getString(KEY_STEP_DATE, "") ?: ""
            val hasBaseline = p.getBoolean(KEY_STEP_HAS_BASELINE, false)

            if (storedDate != today || !hasBaseline) {
                p.edit()
                    .putString(KEY_STEP_DATE, today)
                    .putBoolean(KEY_STEP_HAS_BASELINE, true)
                    .putInt(KEY_STEP_LAST_RAW, raw)
                    .putInt(KEY_STEP_TODAY, 0)
                    .putLong(KEY_STEPS_UPDATED_AT, nowMs)
                    .apply()
                return 0
            }

            val lastRaw = p.getInt(KEY_STEP_LAST_RAW, raw)
            val todayTotal = p.getInt(KEY_STEP_TODAY, 0)
            val delta = if (raw >= lastRaw) (raw - lastRaw) else raw
            val updatedTotal = if (delta > 0) todayTotal + delta else todayTotal

            var walkingSec = p.getInt(KEY_WALKING_TIME_SECONDS, 0)
            val lastBurstMs = p.getLong(KEY_LAST_STEP_BURST_MS, 0L)
            var activity = p.getString(KEY_MOVEMENT_ACTIVITY, "stationary") ?: "stationary"

            if (delta > 0) {
                // Only add active walking duration for genuine consecutive step bursts
                if (lastBurstMs > 0L) {
                    val gapSec = ((nowMs - lastBurstMs) / 1000L).toInt()
                    if (gapSec in 1..45 && delta >= 3) {
                        walkingSec += gapSec.coerceAtMost(20)
                    } else if (delta >= 6) {
                        walkingSec += (delta / 2).coerceIn(2, 10)
                    }
                } else if (delta >= 6) {
                    walkingSec += (delta / 2).coerceIn(2, 10)
                }
                activity = "walking"
            } else if (lastBurstMs > 0L && (nowMs - lastBurstMs) > 90_000L && activity == "walking") {
                activity = "stationary"
            }

            val editor = p.edit()
                .putInt(KEY_STEP_LAST_RAW, raw)
                .putInt(KEY_STEP_TODAY, updatedTotal)
                .putInt(KEY_WALKING_TIME_SECONDS, walkingSec)
                .putString(KEY_MOVEMENT_ACTIVITY, activity)
                .putString(KEY_STEP_SOURCE, computeStepSourceLocked(p, updatedTotal))
            if (delta > 0) {
                editor.putLong(KEY_STEPS_UPDATED_AT, nowMs)
                editor.putLong(KEY_LAST_STEP_BURST_MS, nowMs)
            }
            editor.apply()
            return updatedTotal
        }
    }

    fun applyHealthConnectToday(
        context: Context,
        steps: Int?,
        distanceMeters: Double?,
        nowMs: Long = System.currentTimeMillis()
    ) {
        ensureDayAndArchiveIfNeeded(context, nowMs)
        synchronized(lock) {
            val p = prefs(context)
            val editor = p.edit().putLong(KEY_HC_UPDATED_AT, nowMs)
            if (steps != null && steps >= 0) {
                editor.putInt(KEY_HC_STEPS_TODAY, steps)
            }
            if (distanceMeters != null && distanceMeters >= 0.0) {
                editor.putFloat(KEY_HC_DISTANCE_KM_TODAY, (distanceMeters / 1000.0).toFloat())
            }
            editor.putString(KEY_STEP_SOURCE, if (steps != null && steps >= 0) "health_connect" else computeStepSourceLocked(p, p.getInt(KEY_STEP_TODAY, 0)))
            editor.apply()
        }
    }

    fun readAndRecordBattery(context: Context, batteryIntent: Intent? = null, nowMs: Long = System.currentTimeMillis()): Pair<Int, Boolean> {
        val statusIntent = batteryIntent ?: IntentFilter(Intent.ACTION_BATTERY_CHANGED).let { ifilter ->
            context.applicationContext.registerReceiver(null, ifilter)
        }
        val status = statusIntent?.getIntExtra(BatteryManager.EXTRA_STATUS, -1) ?: -1
        val isCharging = status == BatteryManager.BATTERY_STATUS_CHARGING ||
            status == BatteryManager.BATTERY_STATUS_FULL

        var levelPercent = -1
        val level = statusIntent?.getIntExtra(BatteryManager.EXTRA_LEVEL, -1) ?: -1
        val scale = statusIntent?.getIntExtra(BatteryManager.EXTRA_SCALE, -1) ?: -1
        if (level >= 0 && scale > 0) {
            levelPercent = (level * 100) / scale
        } else {
            val bm = context.applicationContext.getSystemService(Context.BATTERY_SERVICE) as? BatteryManager
            levelPercent = bm?.getIntProperty(BatteryManager.BATTERY_PROPERTY_CAPACITY) ?: -1
        }

        if (levelPercent in 0..100) {
            synchronized(lock) {
                prefs(context).edit()
                    .putInt(KEY_BATTERY_LEVEL, levelPercent)
                    .putBoolean(KEY_BATTERY_CHARGING, isCharging)
                    .putLong(KEY_BATTERY_UPDATED_AT, nowMs)
                    .apply()
            }
        }
        return Pair(levelPercent, isCharging)
    }

    fun readAndRecordNetwork(context: Context, nowMs: Long = System.currentTimeMillis()): String {
        val type = try {
            val cm = context.applicationContext.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
            val net = cm.activeNetwork
            val caps = if (net != null) cm.getNetworkCapabilities(net) else null
            if (caps == null) {
                "offline"
            } else {
                when {
                    caps.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) -> "wifi"
                    caps.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR) -> "mobile"
                    caps.hasTransport(NetworkCapabilities.TRANSPORT_ETHERNET) -> "wifi"
                    else -> "online"
                }
            }
        } catch (_: Exception) {
            "unknown"
        }

        synchronized(lock) {
            prefs(context).edit()
                .putString(KEY_NETWORK_TYPE, type)
                .putLong(KEY_NETWORK_UPDATED_AT, nowMs)
                .apply()
        }
        return type
    }

    fun configureCloudUpload(
        context: Context,
        supabaseUrl: String,
        supabaseKey: String,
        accessToken: String?,
        spaceId: String,
        myUserId: String,
        myName: String
    ) {
        synchronized(lock) {
            prefs(context).edit()
                .putString(KEY_CFG_SUPABASE_URL, supabaseUrl.trim())
                .putString(KEY_CFG_SUPABASE_KEY, supabaseKey.trim())
                .putString(KEY_CFG_ACCESS_TOKEN, (accessToken ?: "").trim())
                .putString(KEY_CFG_SPACE_ID, spaceId.trim())
                .putString(KEY_CFG_MY_USER_ID, myUserId.trim())
                .putString(KEY_CFG_MY_NAME, myName.trim())
                .apply()
        }
    }

    fun appendSyncError(context: Context, source: String, message: String, nowMs: Long = System.currentTimeMillis()) {
        synchronized(lock) {
            val p = prefs(context)
            val raw = p.getString(KEY_SYNC_ERROR_LOG_JSON, "[]") ?: "[]"
            val arr = try { JSONArray(raw) } catch (_: Exception) { JSONArray() }
            arr.put(JSONObject().apply {
                put("tsMs", nowMs)
                put("source", source)
                put("message", message.take(280))
            })
            val trimmed = JSONArray()
            val start = kotlin.math.max(0, arr.length() - 30)
            for (i in start until arr.length()) trimmed.put(arr.get(i))
            p.edit().putString(KEY_SYNC_ERROR_LOG_JSON, trimmed.toString()).apply()
        }
    }

    fun buildTelemetryMap(context: Context, nowMs: Long = System.currentTimeMillis()): Map<String, Any?> {
        ensureDayAndArchiveIfNeeded(context, nowMs)
        val (batteryLevel, isCharging) = readAndRecordBattery(context, null, nowMs)
        val networkType = readAndRecordNetwork(context, nowMs)

        synchronized(lock) {
            val p = prefs(context)
            val effectiveSteps = computeEffectiveStepsLocked(p)
            val screenTimeSec = computeEffectiveScreenTimeLocked(p, nowMs)
            val appTimeSec = computeEffectiveAppTimeLocked(p, nowMs)
            val hcDistKm = p.getFloat(KEY_HC_DISTANCE_KM_TODAY, -1f).toDouble()
            val lastBurstMs = p.getLong(KEY_LAST_STEP_BURST_MS, 0L)
            var movement = p.getString(KEY_MOVEMENT_ACTIVITY, "stationary") ?: "stationary"
            if (movement == "walking" && lastBurstMs > 0L && (nowMs - lastBurstMs) > 90_000L) {
                movement = "stationary"
            }

            val isUnlocked = p.getBoolean(KEY_IS_SCREEN_UNLOCKED, false)
            val isInteractive = try {
                val pm = context.getSystemService(Context.POWER_SERVICE) as? PowerManager
                pm?.isInteractive == true
            } catch (_: Exception) {
                isUnlocked
            }

            return mapOf(
                "dateKey" to (p.getString(KEY_ACTIVE_DATE, todayDateKey(nowMs)) ?: todayDateKey(nowMs)),
                "timeZoneOffsetMinutes" to timezoneOffsetMinutes(nowMs),
                "level" to batteryLevel,
                "batteryLevel" to batteryLevel,
                "isCharging" to isCharging,
                "batteryUpdatedAtMs" to p.getLong(KEY_BATTERY_UPDATED_AT, nowMs),
                "networkType" to networkType,
                "networkUpdatedAtMs" to p.getLong(KEY_NETWORK_UPDATED_AT, nowMs),
                "lastUnlockedAtMs" to p.getLong(KEY_LAST_UNLOCKED, 0L),
                "firstUnlockedAtMs" to p.getLong(KEY_FIRST_UNLOCKED, 0L),
                "lastLockedAtMs" to p.getLong(KEY_LAST_LOCKED, 0L),
                "unlockCountToday" to p.getInt(KEY_UNLOCK_COUNT, 0),
                "lockCountToday" to p.getInt(KEY_LOCK_COUNT, 0),
                "isScreenUnlocked" to isUnlocked,
                "isDeviceUnlocked" to isUnlocked,
                "isScreenOn" to isInteractive,
                "screenTimeSecondsToday" to screenTimeSec,
                "walkingTimeSecondsToday" to p.getInt(KEY_WALKING_TIME_SECONDS, 0),
                "appTimeSecondsToday" to appTimeSec,
                "stepsToday" to if (effectiveSteps >= 0) effectiveSteps else null,
                "distanceKmToday" to if (hcDistKm >= 0.0) hcDistKm else null,
                "stepSource" to computeStepSourceLocked(p, effectiveSteps),
                "stepsUpdatedAtMs" to p.getLong(KEY_STEPS_UPDATED_AT, 0L),
                "movementActivity" to movement,
                "recentScreenEventsJson" to (p.getString(KEY_SCREEN_EVENTS_JSON, "[]") ?: "[]"),
                "recordedAtMs" to nowMs
            )
        }
    }

    fun consumePendingDailySummaryJson(context: Context): String? {
        synchronized(lock) {
            val p = prefs(context)
            val s = p.getString(KEY_COMPLETED_SUMMARY_JSON, null)
            if (!s.isNullOrEmpty()) {
                p.edit().remove(KEY_COMPLETED_SUMMARY_JSON).apply()
            }
            return s
        }
    }

    fun getDebugSnapshot(context: Context, nowMs: Long = System.currentTimeMillis()): Map<String, Any?> {
        val telemetry = buildTelemetryMap(context, nowMs)
        synchronized(lock) {
            val p = prefs(context)
            return mapOf(
                "telemetry" to telemetry,
                "rawStepLast" to p.getInt(KEY_STEP_LAST_RAW, -1),
                "sensorStepsToday" to p.getInt(KEY_STEP_TODAY, 0),
                "hcStepsToday" to p.getInt(KEY_HC_STEPS_TODAY, -1),
                "hcDistanceKmToday" to p.getFloat(KEY_HC_DISTANCE_KM_TODAY, -1f).toDouble(),
                "hcUpdatedAtMs" to p.getLong(KEY_HC_UPDATED_AT, 0L),
                "lastCloudSyncAtMs" to p.getLong(KEY_LAST_CLOUD_SYNC_AT, 0L),
                "syncErrorsJson" to (p.getString(KEY_SYNC_ERROR_LOG_JSON, "[]") ?: "[]"),
                "pendingSummariesJson" to (p.getString(KEY_PENDING_SUMMARIES_JSON, "[]") ?: "[]"),
                "hasCloudConfig" to (!p.getString(KEY_CFG_SUPABASE_URL, "").isNullOrEmpty() && !p.getString(KEY_CFG_SPACE_ID, "").isNullOrEmpty())
            )
        }
    }

    fun uploadSnapshotAndPendingSummaries(context: Context) {
        val nowMs = System.currentTimeMillis()
        ensureDayAndArchiveIfNeeded(context, nowMs)
        val snap = buildTelemetryMap(context, nowMs)
        val urlBase: String
        val anonKey: String
        val accessToken: String
        val spaceId: String
        val userId: String
        val myName: String
        val pendingArr: JSONArray

        synchronized(lock) {
            val p = prefs(context)
            urlBase = p.getString(KEY_CFG_SUPABASE_URL, "") ?: ""
            anonKey = p.getString(KEY_CFG_SUPABASE_KEY, "") ?: ""
            accessToken = p.getString(KEY_CFG_ACCESS_TOKEN, "") ?: ""
            spaceId = p.getString(KEY_CFG_SPACE_ID, "") ?: ""
            userId = p.getString(KEY_CFG_MY_USER_ID, "") ?: ""
            myName = p.getString(KEY_CFG_MY_NAME, "") ?: ""
            val pendingRaw = p.getString(KEY_PENDING_SUMMARIES_JSON, "[]") ?: "[]"
            pendingArr = try { JSONArray(pendingRaw) } catch (_: Exception) { JSONArray() }
        }

        if (urlBase.isEmpty() || anonKey.isEmpty() || spaceId.isEmpty() || userId.isEmpty()) {
            return
        }

        val bearer = if (accessToken.isNotEmpty()) accessToken else anonKey
        val isoFormatter = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'", Locale.US).apply {
            timeZone = TimeZone.getTimeZone("UTC")
        }
        val isoNow = isoFormatter.format(Date(nowMs))

        try {
            val contentJson = JSONObject().apply {
                put("userId", userId)
                put("userName", myName)
                put("dateKey", snap["dateKey"])
                put("timeZoneOffsetMinutes", snap["timeZoneOffsetMinutes"])
                put("level", snap["batteryLevel"])
                put("batteryLevel", snap["batteryLevel"])
                put("isCharging", snap["isCharging"])
                put("batteryUpdatedAtMs", snap["batteryUpdatedAtMs"])
                put("batteryUpdatedAt", formatIsoOrNull(snap["batteryUpdatedAtMs"] as? Long, isoFormatter))
                put("networkType", snap["networkType"])
                put("networkUpdatedAtMs", snap["networkUpdatedAtMs"])
                put("networkUpdatedAt", formatIsoOrNull(snap["networkUpdatedAtMs"] as? Long, isoFormatter))
                put("isScreenOn", snap["isScreenOn"])
                put("isDeviceUnlocked", snap["isDeviceUnlocked"])
                put("lastUnlockedAtMs", snap["lastUnlockedAtMs"])
                put("lastUnlockedAt", formatIsoOrNull(snap["lastUnlockedAtMs"] as? Long, isoFormatter))
                put("firstUnlockedAtMs", snap["firstUnlockedAtMs"])
                put("firstUnlockedAt", formatIsoOrNull(snap["firstUnlockedAtMs"] as? Long, isoFormatter))
                put("lastLockedAtMs", snap["lastLockedAtMs"])
                put("lastLockedAt", formatIsoOrNull(snap["lastLockedAtMs"] as? Long, isoFormatter))
                put("unlockCountToday", snap["unlockCountToday"])
                put("lockCountToday", snap["lockCountToday"])
                put("screenTimeSecondsToday", snap["screenTimeSecondsToday"])
                put("walkingTimeSecondsToday", snap["walkingTimeSecondsToday"])
                put("appTimeSecondsToday", snap["appTimeSecondsToday"])
                put("stepsToday", snap["stepsToday"] ?: JSONObject.NULL)
                put("distanceKmToday", snap["distanceKmToday"] ?: JSONObject.NULL)
                put("stepSource", snap["stepSource"])
                put("stepsUpdatedAtMs", snap["stepsUpdatedAtMs"])
                put("stepsUpdatedAt", formatIsoOrNull(snap["stepsUpdatedAtMs"] as? Long, isoFormatter))
                put("movementActivity", snap["movementActivity"])
                put("recentScreenEvents", try { JSONArray(snap["recentScreenEventsJson"] as? String ?: "[]") } catch (_: Exception) { JSONArray() })
                put("updatedAt", isoNow)
            }

            val rowPayload = JSONObject().apply {
                put("id", "telemetry_${spaceId}_$userId")
                put("content", contentJson)
                put("updated_at", isoNow)
            }

            postSupabaseUpsert(urlBase, anonKey, bearer, rowPayload)

            // Flush any archived daily summaries cleanly
            if (pendingArr.length() > 0) {
                val remaining = JSONArray()
                for (i in 0 until pendingArr.length()) {
                    val item = pendingArr.optJSONObject(i) ?: continue
                    val dKey = item.optString("dateKey")
                    if (dKey.isEmpty()) continue
                    item.put("userId", userId)
                    item.put("spaceId", spaceId)
                    val summaryRow = JSONObject().apply {
                        put("id", "daily_summary_${spaceId}_${userId}_$dKey")
                        put("content", item)
                        put("updated_at", isoNow)
                    }
                    try {
                        postSupabaseUpsert(urlBase, anonKey, bearer, summaryRow)
                    } catch (e: Exception) {
                        remaining.put(item)
                        appendSyncError(context, "daily_summary_upload", e.message ?: "HTTP error")
                    }
                }
                synchronized(lock) {
                    prefs(context).edit().putString(KEY_PENDING_SUMMARIES_JSON, remaining.toString()).apply()
                }
            }

            synchronized(lock) {
                prefs(context).edit().putLong(KEY_LAST_CLOUD_SYNC_AT, nowMs).apply()
            }
        } catch (e: Exception) {
            appendSyncError(context, "bg_telemetry_upload", e.message ?: "HTTP error")
        }
    }

    private fun postSupabaseUpsert(urlBase: String, anonKey: String, bearer: String, rowPayload: JSONObject) {
        val cleanBase = urlBase.trimEnd('/')
        val url = URL("$cleanBase/rest/v1/app_content?on_conflict=id")
        val conn = (url.openConnection() as HttpURLConnection).apply {
            requestMethod = "POST"
            connectTimeout = 10_000
            readTimeout = 10_000
            doOutput = true
            setRequestProperty("apikey", anonKey)
            setRequestProperty("Authorization", "Bearer $bearer")
            setRequestProperty("Content-Type", "application/json")
            setRequestProperty("Prefer", "resolution=merge-duplicates,return=minimal")
        }
        OutputStreamWriter(conn.outputStream, Charsets.UTF_8).use { writer ->
            writer.write(rowPayload.toString())
            writer.flush()
        }
        val code = conn.responseCode
        conn.disconnect()
        if (code !in 200..299) {
            throw RuntimeException("Supabase upsert HTTP $code")
        }
    }

    private fun formatIsoOrNull(ms: Long?, fmt: SimpleDateFormat): Any {
        if (ms == null || ms <= 0L) return JSONObject.NULL
        return fmt.format(Date(ms))
    }

    private fun computeEffectiveStepsLocked(p: android.content.SharedPreferences): Int {
        val sensorSteps = if (p.getBoolean(KEY_STEP_HAS_BASELINE, false)) p.getInt(KEY_STEP_TODAY, 0) else -1
        val hcSteps = p.getInt(KEY_HC_STEPS_TODAY, -1)
        return when {
            hcSteps >= 0 && sensorSteps >= 0 -> kotlin.math.max(hcSteps, sensorSteps)
            hcSteps >= 0 -> hcSteps
            sensorSteps >= 0 -> sensorSteps
            else -> -1
        }
    }

    private fun computeStepSourceLocked(p: android.content.SharedPreferences, effectiveSteps: Int): String {
        val hcSteps = p.getInt(KEY_HC_STEPS_TODAY, -1)
        val sensorSteps = if (p.getBoolean(KEY_STEP_HAS_BASELINE, false)) p.getInt(KEY_STEP_TODAY, 0) else -1
        return when {
            hcSteps >= 0 && (sensorSteps < 0 || hcSteps >= sensorSteps) -> "health_connect"
            sensorSteps >= 0 -> "sensor"
            effectiveSteps >= 0 -> "sensor"
            else -> "none"
        }
    }

    private fun computeEffectiveScreenTimeLocked(p: android.content.SharedPreferences, nowMs: Long): Int {
        var total = p.getInt(KEY_SCREEN_TIME_SECONDS, 0)
        val unlocked = p.getBoolean(KEY_IS_SCREEN_UNLOCKED, false)
        val startMs = p.getLong(KEY_UNLOCK_SESSION_START_MS, 0L)
        if (unlocked && startMs > 0L && nowMs > startMs) {
            total += ((nowMs - startMs) / 1000L).toInt().coerceIn(0, 43200)
        }
        return total
    }

    private fun computeEffectiveAppTimeLocked(p: android.content.SharedPreferences, nowMs: Long): Int {
        var total = p.getInt(KEY_APP_TIME_SECONDS, 0)
        val inFg = p.getBoolean(KEY_APP_IN_FOREGROUND, false)
        val startMs = p.getLong(KEY_APP_SESSION_START_MS, 0L)
        if (inFg && startMs > 0L && nowMs > startMs) {
            total += ((nowMs - startMs) / 1000L).toInt().coerceIn(0, 43200)
        }
        return total
    }
}
