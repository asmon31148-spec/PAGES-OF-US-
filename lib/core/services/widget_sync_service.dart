import 'package:home_widget/home_widget.dart';

class WidgetSyncService {
  static const String appWidgetProvider = 'PagesOfUsWidgetProvider';

  static Future<void> syncWidget({
    String? partnerNickname,
    required String? partnerThought,
    required int daysTogether,
    int? missYouCount,
    List<String>? careLines,
  }) async {
    try {
      await HomeWidget.saveWidgetData<String>(
        'partnerThought',
        partnerThought != null && partnerThought.isNotEmpty
            ? '“$partnerThought”'
            : '“Thinking of you...”',
      );
      await HomeWidget.saveWidgetData<String>(
        'daysTogether',
        'Day $daysTogether together ✦',
      );
      if (partnerNickname != null && partnerNickname.isNotEmpty) {
        await HomeWidget.saveWidgetData<String>('partnerNickname', partnerNickname);
      }
      final touches = (missYouCount != null && missYouCount > 0) ? missYouCount : 14;
      await HomeWidget.saveWidgetData<String>(
        'missYouCount',
        '$touches Touches Today ❤️',
      );

      if (careLines != null && careLines.isNotEmpty) {
        if (careLines.isNotEmpty) await HomeWidget.saveWidgetData<String>('careLine1', careLines[0]);
        if (careLines.length > 1) await HomeWidget.saveWidgetData<String>('careLine2', careLines[1]);
        if (careLines.length > 2) await HomeWidget.saveWidgetData<String>('careLine3', careLines[2]);
      }

      await HomeWidget.updateWidget(
        name: appWidgetProvider,
        androidName: appWidgetProvider,
        qualifiedAndroidName: 'com.pagesofus.app.PagesOfUsWidgetProvider',
      );
    } catch (_) {
      // Ignored if widget is not active
    }
  }
}
