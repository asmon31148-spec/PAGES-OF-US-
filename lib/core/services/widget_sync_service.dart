import 'package:home_widget/home_widget.dart';

class WidgetSyncService {
  static const String appWidgetProvider = 'PagesOfUsWidgetProvider';

  static Future<void> syncWidget({
    required String? partnerName,
    required String? partnerThought,
    required int daysTogether,
  }) async {
    try {
      await HomeWidget.saveWidgetData<String>(
        'partnerName',
        partnerName ?? 'Partner',
      );
      await HomeWidget.saveWidgetData<String>(
        'partnerThought',
        partnerThought ?? 'Thinking of you...',
      );
      await HomeWidget.saveWidgetData<String>(
        'daysTogether',
        'Day $daysTogether together ✦',
      );

      await HomeWidget.updateWidget(
        name: appWidgetProvider,
        androidName: appWidgetProvider,
      );
    } catch (_) {
      // Ignored if widget is not active
    }
  }
}
