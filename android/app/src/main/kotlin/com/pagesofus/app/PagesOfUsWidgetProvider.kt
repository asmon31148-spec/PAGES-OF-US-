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
                    ?: legacyPrefs.getString("daysTogether", "Together ✦")
                    ?: "Together ✦"

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

                val currentView = statePrefs.getInt("currentView", 1) // 0 = care, 1 = note, 2 = miss you

                val views = RemoteViews(context.packageName, R.layout.pages_of_us_widget)

                // Set texts
                views.setTextViewText(R.id.widget_days_together, daysTogether)
                views.setTextViewText(R.id.widget_partner_thought, partnerThought)
                views.setTextViewText(R.id.widget_note_author, "— from $partnerNickname")
                views.setTextViewText(R.id.widget_miss_you_count, missYouCount)
                views.setTextViewText(R.id.widget_care_line1, careLine1)
                views.setTextViewText(R.id.widget_care_line2, careLine2)
                views.setTextViewText(R.id.widget_care_line3, careLine3)

                // Highlight active tab
                val activeColor = 0xFFE07A5F.toInt()
                val inactiveColor = 0xFFEDEAE5.toInt()
                views.setTextColor(R.id.widget_btn_care, if (currentView == 0) activeColor else inactiveColor)
                views.setTextColor(R.id.widget_btn_note, if (currentView == 1) activeColor else inactiveColor)
                views.setTextColor(R.id.widget_btn_miss, if (currentView == 2) activeColor else inactiveColor)

                views.setTextViewText(R.id.widget_btn_care, if (currentView == 0) "🌿 Care ✦" else "🌿 Care")
                views.setTextViewText(R.id.widget_btn_note, if (currentView == 1) "💌 Note ✦" else "💌 Note")
                views.setTextViewText(R.id.widget_btn_miss, if (currentView == 2) "❤️ Miss ✦" else "❤️ Miss")

                // Toggle 3 Switchable Views
                views.setViewVisibility(R.id.widget_view_care, if (currentView == 0) View.VISIBLE else View.GONE)
                views.setViewVisibility(R.id.widget_view_note, if (currentView == 1) View.VISIBLE else View.GONE)
                views.setViewVisibility(R.id.widget_view_miss_you, if (currentView == 2) View.VISIBLE else View.GONE)

                // Setup Tab 1 PendingIntent (Care)
                val careIntent = Intent(context, PagesOfUsWidgetProvider::class.java).apply {
                    action = ACTION_SWITCH_VIEW
                    putExtra(EXTRA_VIEW_INDEX, 0)
                }
                val carePi = PendingIntent.getBroadcast(
                    context, 1001, careIntent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
                views.setOnClickPendingIntent(R.id.widget_btn_care, carePi)

                // Setup Tab 2 PendingIntent (Note)
                val noteIntent = Intent(context, PagesOfUsWidgetProvider::class.java).apply {
                    action = ACTION_SWITCH_VIEW
                    putExtra(EXTRA_VIEW_INDEX, 1)
                }
                val notePi = PendingIntent.getBroadcast(
                    context, 1002, noteIntent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
                views.setOnClickPendingIntent(R.id.widget_btn_note, notePi)

                // Setup Tab 3 PendingIntent (Miss You)
                val missIntent = Intent(context, PagesOfUsWidgetProvider::class.java).apply {
                    action = ACTION_SWITCH_VIEW
                    putExtra(EXTRA_VIEW_INDEX, 2)
                }
                val missPi = PendingIntent.getBroadcast(
                    context, 1003, missIntent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
                views.setOnClickPendingIntent(R.id.widget_btn_miss, missPi)

                // Click on root or center container opens MainActivity
                val appIntent = Intent(context, MainActivity::class.java).apply {
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                }
                val appPi = PendingIntent.getActivity(
                    context, 0, appIntent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
                views.setOnClickPendingIntent(R.id.widget_root, appPi)
                views.setOnClickPendingIntent(R.id.widget_center_container, appPi)

                appWidgetManager.updateAppWidget(appWidgetId, views)
            } catch (e: Exception) {
                Log.e("PagesOfUsWidget", "Error updating widget: ${e.message}", e)
            }
        }
    }

    override fun onReceive(context: Context, intent: Intent?) {
        super.onReceive(context, intent)

        if (intent != null && ACTION_SWITCH_VIEW == intent.action) {
            val targetView = intent.getIntExtra(EXTRA_VIEW_INDEX, 1)
            val statePrefs = context.getSharedPreferences("PagesOfUsWidgetState", Context.MODE_PRIVATE)
            statePrefs.edit().putInt("currentView", targetView).apply()

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
