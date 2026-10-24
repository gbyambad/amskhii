import 'package:flutter/material.dart';

import 'app_colors.dart';

abstract final class AppTheme {
  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.accent,
      primary: AppColors.accent,
      onPrimary: Colors.white,
      surface: AppColors.surface,
      onSurface: AppColors.ink,
    );
    final base = ThemeData(useMaterial3: true, colorScheme: scheme, fontFamily: 'Onest');

    return base.copyWith(
      scaffoldBackgroundColor: AppColors.ground,
      textTheme: base.textTheme.apply(bodyColor: AppColors.ink, displayColor: AppColors.ink),
      switchTheme: SwitchThemeData(
        thumbColor: const WidgetStatePropertyAll(Colors.white),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? AppColors.accent : AppColors.inactive,
        ),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: AppColors.accent.withValues(alpha: 0.12),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: states.contains(WidgetState.selected) ? AppColors.accent : AppColors.muted,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected) ? AppColors.accent : AppColors.muted,
          ),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
        dragHandleColor: Color(0xFFD5D9E2),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: const TextStyle(fontFamily: 'Onest', fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      dividerTheme: const DividerThemeData(color: AppColors.divider, space: 1, thickness: 1),
    );
  }
}

/// Text styles that sit outside the Material type scale.
abstract final class AppText {
  /// Large numerals (`4ц 12м`, `87`). Unbounded lacks Ө/Ү, hence the fallback.
  static TextStyle numeric(double size, {Color color = AppColors.ink}) => TextStyle(
        fontFamily: 'Unbounded',
        fontFamilyFallback: const ['Onest'],
        fontSize: size,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.02 * size,
        height: 1,
        color: color,
      );

  static const screenTitle = TextStyle(fontSize: 28, fontWeight: FontWeight.w700, letterSpacing: -0.3);
  static const cardTitle = TextStyle(fontSize: 16, fontWeight: FontWeight.w700);
  static const label = TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.muted);
  static const rowTitle = TextStyle(fontSize: 15, fontWeight: FontWeight.w600);
  static const body = TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.muted, height: 1.4);
  static const caption = TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.muted);
}
