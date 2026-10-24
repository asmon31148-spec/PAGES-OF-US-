package com.pagesofus.app;

import android.appwidget.AppWidgetManager;
import android.content.ComponentName;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.os.Bundle;
import android.view.View;
import android.webkit.JavascriptInterface;
import android.webkit.WebView;
import com.getcapacitor.BridgeActivity;

public class MainActivity extends BridgeActivity {

    public class WidgetBridge {
        private final Context context;

        public WidgetBridge(Context context) {
            this.context = context;
        }

        @JavascriptInterface
        public void updateWidget(String partnerName, String partnerThought, String daysTogether) {
            try {
                SharedPreferences prefs = context.getSharedPreferences("PagesOfUsWidget", Context.MODE_PRIVATE);
                prefs.edit()
                    .putString("partnerName", partnerName != null ? partnerName : "Partner")
                    .putString("partnerThought", partnerThought != null ? partnerThought : "Thinking of you...")
                    .putString("daysTogether", daysTogether != null ? daysTogether : "Together ✦")
                    .apply();

                Intent intent = new Intent(context, PagesOfUsWidgetProvider.class);
                intent.setAction(AppWidgetManager.ACTION_APPWIDGET_UPDATE);
                int[] ids = AppWidgetManager.getInstance(context).getAppWidgetIds(new ComponentName(context, PagesOfUsWidgetProvider.class));
                intent.putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, ids);
                context.sendBroadcast(intent);
            } catch (Exception e) {
                // Graceful fallback
            }
        }
    }

    @Override
    public void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        try {
            WebView webView = getBridge().getWebView();
            if (webView != null) {
                webView.setVerticalScrollBarEnabled(false);
                webView.setHorizontalScrollBarEnabled(false);
                webView.setScrollBarStyle(View.SCROLLBARS_INSIDE_OVERLAY);
                webView.setOverScrollMode(View.OVER_SCROLL_NEVER);
                webView.addJavascriptInterface(new WidgetBridge(this), "AndroidWidget");
            }
        } catch (Exception e) {
            // graceful fallback
        }
    }
}
