package com.pagesofus.app;

import android.app.PendingIntent;
import android.appwidget.AppWidgetManager;
import android.appwidget.AppWidgetProvider;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.widget.RemoteViews;

public class PagesOfUsWidgetProvider extends AppWidgetProvider {

    @Override
    public void onUpdate(Context context, AppWidgetManager appWidgetManager, int[] appWidgetIds) {
        for (int appWidgetId : appWidgetIds) {
            updateAppWidget(context, appWidgetManager, appWidgetId);
        }
    }

    public static void updateAppWidget(Context context, AppWidgetManager appWidgetManager, int appWidgetId) {
        SharedPreferences prefs = context.getSharedPreferences("PagesOfUsWidget", Context.MODE_PRIVATE);
        String partnerName = prefs.getString("partnerName", "Partner");
        String partnerThought = prefs.getString("partnerThought", "Thinking of you...");
        String daysTogether = prefs.getString("daysTogether", "Together ✦");

        RemoteViews views = new RemoteViews(context.getPackageName(), R.layout.pages_of_us_widget);
        views.setTextViewText(R.id.widget_partner_name, partnerName);
        views.setTextViewText(R.id.widget_partner_thought, partnerThought);
        views.setTextViewText(R.id.widget_days_together, daysTogether);

        String initial = partnerName.length() > 0 ? partnerName.substring(0, 1).toUpperCase() : "♥";
        views.setTextViewText(R.id.widget_avatar_initial, initial);

        // Click on widget opens MainActivity
        Intent intent = new Intent(context, MainActivity.class);
        intent.setFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_CLEAR_TOP);
        PendingIntent pendingIntent = PendingIntent.getActivity(
            context,
            0,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE
        );
        views.setOnClickPendingIntent(R.id.widget_root, pendingIntent);

        appWidgetManager.updateAppWidget(appWidgetId, views);
    }
}
