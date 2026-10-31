package com.pagesofus.app;

import android.app.PendingIntent;
import android.appwidget.AppWidgetManager;
import android.appwidget.AppWidgetProvider;
import android.content.ComponentName;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.util.Log;
import android.view.View;
import android.widget.RemoteViews;

import es.antonborri.home_widget.HomeWidgetPlugin;

public class PagesOfUsWidgetProvider extends AppWidgetProvider {

    public static final String ACTION_SWITCH_VIEW = "com.pagesofus.app.ACTION_SWITCH_WIDGET_VIEW";
    public static final String EXTRA_VIEW_INDEX = "extra_view_index";

    @Override
    public void onReceive(Context context, Intent intent) {
        super.onReceive(context, intent);

        if (intent != null && ACTION_SWITCH_VIEW.equals(intent.getAction())) {
            int targetView = intent.getIntExtra(EXTRA_VIEW_INDEX, 1);
            SharedPreferences statePrefs = context.getSharedPreferences("PagesOfUsWidgetState", Context.MODE_PRIVATE);
            statePrefs.edit().putInt("currentView", targetView).apply();

            AppWidgetManager appWidgetManager = AppWidgetManager.getInstance(context);
            ComponentName thisWidget = new ComponentName(context, PagesOfUsWidgetProvider.class);
            int[] appWidgetIds = appWidgetManager.getAppWidgetIds(thisWidget);
            if (appWidgetIds != null) {
                for (int widgetId : appWidgetIds) {
                    updateAppWidget(context, appWidgetManager, widgetId);
                }
            }
        }
    }

    @Override
    public void onUpdate(Context context, AppWidgetManager appWidgetManager, int[] appWidgetIds) {
        if (appWidgetIds != null) {
            for (int appWidgetId : appWidgetIds) {
                updateAppWidget(context, appWidgetManager, appWidgetId);
            }
        }
    }

    public static void updateAppWidget(Context context, AppWidgetManager appWidgetManager, int appWidgetId) {
        try {
            // Read widget data from home_widget preferences
            SharedPreferences homeWidgetPrefs = null;
            try {
                homeWidgetPrefs = HomeWidgetPlugin.getData(context);
            } catch (Throwable t) {
                Log.w("PagesOfUsWidget", "HomeWidgetPlugin.getData fallback: " + t.getMessage());
            }

            SharedPreferences statePrefs = context.getSharedPreferences("PagesOfUsWidgetState", Context.MODE_PRIVATE);

            String partnerThought = homeWidgetPrefs != null ? homeWidgetPrefs.getString("partnerThought", null) : null;
            if (partnerThought == null || partnerThought.isEmpty()) {
                SharedPreferences legacyPrefs = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE);
                partnerThought = legacyPrefs.getString("partnerThought", null);
            }
            if (partnerThought == null || partnerThought.isEmpty()) {
                partnerThought = "“Thinking of you...”";
            }

            String daysTogether = homeWidgetPrefs != null ? homeWidgetPrefs.getString("daysTogether", "Together ✦") : "Together ✦";
            String partnerNickname = homeWidgetPrefs != null ? homeWidgetPrefs.getString("partnerNickname", "your partner") : "your partner";
            String missYouCount = homeWidgetPrefs != null ? homeWidgetPrefs.getString("missYouCount", "14 Touches Today ❤️") : "14 Touches Today ❤️";
            String careLine1 = homeWidgetPrefs != null ? homeWidgetPrefs.getString("careLine1", "💧 Morning Hydration") : "💧 Morning Hydration";
            String careLine2 = homeWidgetPrefs != null ? homeWidgetPrefs.getString("careLine2", "🥗 Mindful Lunch & Breather") : "🥗 Mindful Lunch & Breather";
            String careLine3 = homeWidgetPrefs != null ? homeWidgetPrefs.getString("careLine3", "🌙 Sweet Sleep & Whispers") : "🌙 Sweet Sleep & Whispers";

            int currentView = statePrefs.getInt("currentView", 1); // 0 = care, 1 = note, 2 = miss you

            RemoteViews views = new RemoteViews(context.getPackageName(), R.layout.pages_of_us_widget);

            // Set texts
            views.setTextViewText(R.id.widget_days_together, daysTogether);
            views.setTextViewText(R.id.widget_partner_thought, partnerThought);
            views.setTextViewText(R.id.widget_note_author, "— from " + partnerNickname);
            views.setTextViewText(R.id.widget_miss_you_count, missYouCount);
            views.setTextViewText(R.id.widget_care_line1, careLine1);
            views.setTextViewText(R.id.widget_care_line2, careLine2);
            views.setTextViewText(R.id.widget_care_line3, careLine3);

            // Highlight active tab
            views.setTextColor(R.id.widget_btn_care, currentView == 0 ? 0xFFE07A5F : 0xFFEDEAE5);
            views.setTextColor(R.id.widget_btn_note, currentView == 1 ? 0xFFE07A5F : 0xFFEDEAE5);
            views.setTextColor(R.id.widget_btn_miss, currentView == 2 ? 0xFFE07A5F : 0xFFEDEAE5);

            views.setTextViewText(R.id.widget_btn_care, currentView == 0 ? "🌿 Care ✦" : "🌿 Care");
            views.setTextViewText(R.id.widget_btn_note, currentView == 1 ? "💌 Note ✦" : "💌 Note");
            views.setTextViewText(R.id.widget_btn_miss, currentView == 2 ? "❤️ Miss ✦" : "❤️ Miss");

            // Toggle 3 Switchable Views
            views.setViewVisibility(R.id.widget_view_care, currentView == 0 ? View.VISIBLE : View.GONE);
            views.setViewVisibility(R.id.widget_view_note, currentView == 1 ? View.VISIBLE : View.GONE);
            views.setViewVisibility(R.id.widget_view_miss_you, currentView == 2 ? View.VISIBLE : View.GONE);

            // Setup Tab 1 PendingIntent (Care)
            Intent careIntent = new Intent(context, PagesOfUsWidgetProvider.class);
            careIntent.setAction(ACTION_SWITCH_VIEW);
            careIntent.putExtra(EXTRA_VIEW_INDEX, 0);
            PendingIntent carePi = PendingIntent.getBroadcast(
                context, 1001, careIntent, PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE
            );
            views.setOnClickPendingIntent(R.id.widget_btn_care, carePi);

            // Setup Tab 2 PendingIntent (Note)
            Intent noteIntent = new Intent(context, PagesOfUsWidgetProvider.class);
            noteIntent.setAction(ACTION_SWITCH_VIEW);
            noteIntent.putExtra(EXTRA_VIEW_INDEX, 1);
            PendingIntent notePi = PendingIntent.getBroadcast(
                context, 1002, noteIntent, PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE
            );
            views.setOnClickPendingIntent(R.id.widget_btn_note, notePi);

            // Setup Tab 3 PendingIntent (Miss You)
            Intent missIntent = new Intent(context, PagesOfUsWidgetProvider.class);
            missIntent.setAction(ACTION_SWITCH_VIEW);
            missIntent.putExtra(EXTRA_VIEW_INDEX, 2);
            PendingIntent missPi = PendingIntent.getBroadcast(
                context, 1003, missIntent, PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE
            );
            views.setOnClickPendingIntent(R.id.widget_btn_miss, missPi);

            // Click on root or center container opens MainActivity
            Intent appIntent = new Intent(context, MainActivity.class);
            appIntent.setFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_CLEAR_TOP);
            PendingIntent appPi = PendingIntent.getActivity(
                context, 0, appIntent, PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE
            );
            views.setOnClickPendingIntent(R.id.widget_root, appPi);
            views.setOnClickPendingIntent(R.id.widget_center_container, appPi);

            appWidgetManager.updateAppWidget(appWidgetId, views);
        } catch (Exception e) {
            Log.e("PagesOfUsWidget", "Error updating widget: " + e.getMessage(), e);
        }
    }
}
