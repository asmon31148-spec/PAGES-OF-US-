package com.pagesofus.app

import android.app.Activity
import android.content.Context
import android.content.Intent
import androidx.health.connect.client.HealthConnectClient
import androidx.health.connect.client.PermissionController
import androidx.health.connect.client.permission.HealthPermission
import androidx.health.connect.client.records.DistanceRecord
import androidx.health.connect.client.records.StepsRecord
import androidx.health.connect.client.request.AggregateRequest
import androidx.health.connect.client.time.TimeRangeFilter
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId

object HealthConnectHelper {
    const val REQ_HEALTH_CONNECT_PERMISSIONS = 9104

    val REQUIRED_PERMISSIONS: Set<String> = setOf(
        HealthPermission.getReadPermission(StepsRecord::class),
        HealthPermission.getReadPermission(DistanceRecord::class)
    )

    fun isSdkAvailable(context: Context): Boolean {
        return try {
            HealthConnectClient.getSdkStatus(context) == HealthConnectClient.SDK_AVAILABLE
        } catch (_: Exception) {
            false
        }
    }

    fun sdkStatusString(context: Context): String {
        return try {
            when (HealthConnectClient.getSdkStatus(context)) {
                HealthConnectClient.SDK_AVAILABLE -> "available"
                HealthConnectClient.SDK_UNAVAILABLE_PROVIDER_UPDATE_REQUIRED -> "update_required"
                else -> "unavailable"
            }
        } catch (_: Exception) {
            "unavailable"
        }
    }

    suspend fun hasAllPermissions(context: Context): Boolean {
        if (!isSdkAvailable(context)) return false
        return try {
            val client = HealthConnectClient.getOrCreate(context)
            val granted = client.permissionController.getGrantedPermissions()
            granted.containsAll(REQUIRED_PERMISSIONS)
        } catch (_: Exception) {
            false
        }
    }

    fun launchPermissionRequest(activity: Activity): Boolean {
        if (!isSdkAvailable(activity)) {
            return openHealthConnectSettings(activity)
        }
        return try {
            val contract = PermissionController.createRequestPermissionResultContract()
            val intent = contract.createIntent(activity, REQUIRED_PERMISSIONS)
            @Suppress("DEPRECATION")
            activity.startActivityForResult(intent, REQ_HEALTH_CONNECT_PERMISSIONS)
            true
        } catch (_: Exception) {
            openHealthConnectSettings(activity)
        }
    }

    fun openHealthConnectSettings(context: Context): Boolean {
        return try {
            val intent = Intent(HealthConnectClient.ACTION_HEALTH_CONNECT_SETTINGS).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            context.startActivity(intent)
            true
        } catch (_: Exception) {
            false
        }
    }

    suspend fun readTodayStepsAndDistance(context: Context): Map<String, Any?> {
        val status = sdkStatusString(context)
        if (status != "available") {
            return mapOf(
                "status" to status,
                "hasPermissions" to false,
                "steps" to null,
                "distanceKm" to null
            )
        }
        return try {
            val client = HealthConnectClient.getOrCreate(context)
            val granted = client.permissionController.getGrantedPermissions()
            val hasPerms = granted.containsAll(REQUIRED_PERMISSIONS)
            if (!hasPerms) {
                return mapOf(
                    "status" to status,
                    "hasPermissions" to false,
                    "steps" to null,
                    "distanceKm" to null
                )
            }
            val zone = ZoneId.systemDefault()
            val startInstant = LocalDate.now(zone).atStartOfDay(zone).toInstant()
            val nowInstant = Instant.now()
            val response = client.aggregate(
                AggregateRequest(
                    metrics = setOf(StepsRecord.COUNT_TOTAL, DistanceRecord.DISTANCE_TOTAL),
                    timeRangeFilter = TimeRangeFilter.between(startInstant, nowInstant)
                )
            )
            val steps = response[StepsRecord.COUNT_TOTAL]?.toInt()
            val distanceMeters = response[DistanceRecord.DISTANCE_TOTAL]?.inMeters
            SanctuaryTelemetryStore.applyHealthConnectToday(context, steps, distanceMeters)
            mapOf(
                "status" to status,
                "hasPermissions" to true,
                "steps" to steps,
                "distanceKm" to if (distanceMeters != null) (distanceMeters / 1000.0) else null
            )
        } catch (e: Exception) {
            SanctuaryTelemetryStore.appendSyncError(context, "health_connect", e.message ?: "Read failed")
            mapOf(
                "status" to "error",
                "hasPermissions" to false,
                "steps" to null,
                "distanceKm" to null,
                "error" to (e.message ?: "error")
            )
        }
    }
}
