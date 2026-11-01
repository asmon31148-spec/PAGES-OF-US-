package com.pagesofus.app

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.util.Log
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetPlugin

class PagesOfUsWidgetProvider : AppWidgetProvider() {

    companion object {
        const val ACTION_SWITCH_VIEW = "com.pagesofus.app.ACTION_SWITCH_WIDGET_VIEW"
        const val ACTION_NEXT_PAGE = "com.pagesofus.app.ACTION_NEXT_WIDGET_PAGE"
        const val ACTION_PREV_PAGE = "com.pagesofus.app.ACTION_PREV_WIDGET_PAGE"
        const val EXTRA_VIEW_INDEX = "extra_view_index"

        fun updateAppWidget(context: Context, appWidgetManager: AppWidgetManager, appWidgetId: Int) {
            try {
                val homeWidgetPrefs: SharedPreferences? = try {
                    HomeWidgetPlugin.getData(context)
                } catch (t: Throwable) {
                    Log.w("PagesOfUsWidget", "HomeWidgetPlugin.getData fallback: ${t.message}")
                    null
                }

                val legacyPrefs = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
                val statePrefs = context.getSharedPreferences("PagesOfUsWidgetState", Context.MODE_PRIVATE)

                var partnerThought = homeWidgetPrefs?.getString("partnerThought", null)
                if (partnerThought.isNullOrEmpty()) {
                    partnerThought = legacyPrefs.getString("partnerThought", null)
                }
                if (partnerThought.isNullOrEmpty()) {
                    partnerThought = "“Thinking of you...”"
                }

                val daysTogether = homeWidgetPrefs?.getString("daysTogether", null)
                    ?: legacyPrefs.getString("daysTogether", "Day 0 together ✦")
                    ?: "Day 0 together ✦"

                val partnerNickname = homeWidgetPrefs?.getString("partnerNickname", null)
                    ?: legacyPrefs.getString("partnerNickname", "your partner")
                    ?: "your partner"

                val missYouCount = homeWidgetPrefs?.getString("missYouCount", null)
                    ?: legacyPrefs.getString("missYouCount", "14 Touches Today ❤️")
                    ?: "14 Touches Today ❤️"

                val careLine1 = homeWidgetPrefs?.getString("careLine1", null)
                    ?: legacyPrefs.getString("careLine1", "💧 Morning Hydration")
                    ?: "💧 Morning Hydration"

                val careLine2 = homeWidgetPrefs?.getString("careLine2", null)
                    ?: legacyPrefs.getString("careLine2", "🥗 Mindful Lunch & Breather")
                    ?: "🥗 Mindful Lunch & Breather"

                val careLine3 = homeWidgetPrefs?.getString("careLine3", null)
                    ?: legacyPrefs.getString("careLine3", "🌙 Sweet Sleep & Whispers")
                    ?: "🌙 Sweet Sleep & Whispers"

                val currentView = statePrefs.getInt("currentView", 1) // 0 = care, 1 = note (default), 2 = miss you

                val views = RemoteViews(context.packageName, R.layout.pages_of_us_widget)

                // 1. Populate Text Content
                views.setTextViewText(R.id.widget_days_together, daysTogether)
                views.setTextViewText(R.id.widget_partner_thought, partnerThought)
                views.setTextViewText(R.id.widget_note_author, "— with love, $partnerNickname")
                views.setTextViewText(R.id.widget_miss_you_count, missYouCount)
                views.setTextViewText(R.id.widget_care_line1, careLine1)
                views.setTextViewText(R.id.widget_care_line2, careLine2)
                views.setTextViewText(R.id.widget_care_line3, careLine3)

                // 2. Active View Visibility Toggle
                views.setViewVisibility(R.id.widget_view_care, if (currentView == 0) View.VISIBLE else View.GONE)
                views.setViewVisibility(R.id.widget_view_note, if (currentView == 1) View.VISIBLE else View.GONE)
                views.setViewVisibility(R.id.widget_view_miss_you, if (currentView == 2) View.VISIBLE else View.GONE)

                // 3. Highlight Dot Carousel Indicators (Warm Rose Gold when active)
                val activeDotColor = 0xFFE07A5F.toInt()
                val inactiveDotColor = 0xFF4A4358.toInt()
                views.setTextColor(R.id.widget_dot_0, if (currentView == 0) activeDotColor else inactiveDotColor)
                views.setTextColor(R.id.widget_dot_1, if (currentView == 1) activeDotColor else inactiveDotColor)
                views.setTextColor(R.id.widget_dot_2, if (currentView == 2) activeDotColor else inactiveDotColor)

                // 4. Interactive Navigation PendingIntents
                // Next Page (Tapping Center Card or Right Arrow '›')
                val nextIntent = Intent(context, PagesOfUsWidgetProvider::class.java).apply {
                    action = ACTION_NEXT_PAGE
                }
                val nextPi = PendingIntent.getBroadcast(
                    context, 2001, nextIntent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
                views.setOnClickPendingIntent(R.id.widget_center_container, nextPi)
                views.setOnClickPendingIntent(R.id.widget_btn_next, nextPi)

                // Previous Page (Tapping Left Arrow '‹')
                val prevIntent = Intent(context, PagesOfUsWidgetProvider::class.java).apply {
                    action = ACTION_PREV_PAGE
                }
                val prevPi = PendingIntent.getBroadcast(
                    context, 2002, prevIntent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
                views.setOnClickPendingIntent(R.id.widget_btn_prev, prevPi)

                // Direct Dot Jumps (Tapping individual dots)
                fun makeDotPi(index: Int): PendingIntent {
                    val dotIntent = Intent(context, PagesOfUsWidgetProvider::class.java).apply {
                        action = ACTION_SWITCH_VIEW
                        putExtra(EXTRA_VIEW_INDEX, index)
                    }
                    return PendingIntent.getBroadcast(
                        context, 3000 + index, dotIntent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                    )
                }
                views.setOnClickPendingIntent(R.id.widget_dot_0, makeDotPi(0))
                views.setOnClickPendingIntent(R.id.widget_dot_1, makeDotPi(1))
                views.setOnClickPendingIntent(R.id.widget_dot_2, makeDotPi(2))

                // Launch App on Header or Root Click
                val appIntent = Intent(context, MainActivity::class.java).apply {
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                }
                val appPi = PendingIntent.getActivity(
                    context, 0, appIntent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
                views.setOnClickPendingIntent(R.id.widget_header_container, appPi)
                views.setOnClickPendingIntent(R.id.widget_root, appPi)

                appWidgetManager.updateAppWidget(appWidgetId, views)
            } catch (e: Exception) {
                Log.e("PagesOfUsWidget", "Error updating widget: ${e.message}", e)
            }
        }
    }

    override fun onReceive(context: Context, intent: Intent?) {
        super.onReceive(context, intent)

        if (intent == null) return
        val statePrefs = context.getSharedPreferences("PagesOfUsWidgetState", Context.MODE_PRIVATE)
        var shouldUpdate = false

        when (intent.action) {
            ACTION_SWITCH_VIEW -> {
                val targetView = intent.getIntExtra(EXTRA_VIEW_INDEX, 1)
                statePrefs.edit().putInt("currentView", targetView).apply()
                shouldUpdate = true
            }
            ACTION_NEXT_PAGE -> {
                val current = statePrefs.getInt("currentView", 1)
                val next = (current + 1) % 3
                statePrefs.edit().putInt("currentView", next).apply()
                shouldUpdate = true
            }
            ACTION_PREV_PAGE -> {
                val current = statePrefs.getInt("currentView", 1)
                val prev = (current + 2) % 3
                statePrefs.edit().putInt("currentView", prev).apply()
                shouldUpdate = true
            }
        }

        if (shouldUpdate) {
            val appWidgetManager = AppWidgetManager.getInstance(context)
            val thisWidget = ComponentName(context, PagesOfUsWidgetProvider::class.java)
            val appWidgetIds = appWidgetManager.getAppWidgetIds(thisWidget)
            if (appWidgetIds != null) {
                for (widgetId in appWidgetIds) {
                    updateAppWidget(context, appWidgetManager, widgetId)
                }
            }
        }
    }

    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray?) {
        if (appWidgetIds != null) {
            for (appWidgetId in appWidgetIds) {
                updateAppWidget(context, appWidgetManager, appWidgetId)
            }
        }
    }
}
