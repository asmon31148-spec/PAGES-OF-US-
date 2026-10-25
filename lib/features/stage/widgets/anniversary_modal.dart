import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../providers/theme_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/stage_provider.dart';

class AnniversaryModal {
  static Future<void> show(BuildContext context) async {
    final stageProvider = context.read<StageProvider>();
    final authProvider = context.read<AuthProvider>();
    final space = authProvider.space;

    DateTime initialDate = DateTime.now();
    if (stageProvider.anniversaryDate != null &&
        stageProvider.anniversaryDate!.isNotEmpty) {
      try {
        initialDate = DateTime.parse(stageProvider.anniversaryDate!);
      } catch (_) {}
    }

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(1980),
      lastDate: DateTime.now(),
      builder: (context, child) {
        final isDark = context.read<ThemeProvider>().isDark;
        return Theme(
          data: isDark
              ? ThemeData.dark().copyWith(
                  colorScheme: const ColorScheme.dark(
                    primary: AppColors.sage,
                    onPrimary: Colors.white,
                    surface: AppColors.darkSurface,
                    onSurface: AppColors.darkInk,
                  ),
                )
              : ThemeData.light().copyWith(
                  colorScheme: const ColorScheme.light(
                    primary: AppColors.sage,
                    onPrimary: Colors.white,
                    surface: AppColors.lightSurface,
                    onSurface: AppColors.lightInk,
                  ),
                ),
          child: child!,
        );
      },
    );

    if (picked != null && space != null) {
      final dateStr =
          "${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
      await stageProvider.setAnniversary(space.id, dateStr);
    }
  }
}
