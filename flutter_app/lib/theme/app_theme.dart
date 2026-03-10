import 'package:fluent_ui/fluent_ui.dart';

class AppColors {
  // Primary (Indigo)
  static const primary50 = Color(0xFFEEF2FF);
  static const primary100 = Color(0xFFE0E7FF);
  static const primary200 = Color(0xFFC7D2FE);
  static const primary500 = Color(0xFF6366F1);
  static const primary600 = Color(0xFF4F46E5);
  static const primary700 = Color(0xFF4338CA);

  // Background
  static const background = Color(0xFFF8FAFC);
  static const foreground = Color(0xFF1E293B);

  // Slate
  static const slate50 = Color(0xFFF8FAFC);
  static const slate100 = Color(0xFFF1F5F9);
  static const slate200 = Color(0xFFE2E8F0);
  static const slate300 = Color(0xFFCBD5E1);
  static const slate400 = Color(0xFF94A3B8);
  static const slate500 = Color(0xFF64748B);
  static const slate600 = Color(0xFF475569);
  static const slate700 = Color(0xFF334155);
  static const slate800 = Color(0xFF1E293B);

  // Status Colors
  static const emerald50 = Color(0xFFECFDF5);
  static const emerald400 = Color(0xFF34D399);
  static const emerald700 = Color(0xFF047857);

  static const blue50 = Color(0xFFEFF6FF);
  static const blue400 = Color(0xFF60A5FA);
  static const blue700 = Color(0xFF1D4ED8);

  static const purple50 = Color(0xFFF5F3FF);
  static const purple400 = Color(0xFFA78BFA);
  static const purple700 = Color(0xFF6D28D9);

  static const amber50 = Color(0xFFFFFBEB);
  static const amber400 = Color(0xFFFBBF24);
  static const amber700 = Color(0xFFB45309);

  static const rose50 = Color(0xFFFFF1F2);
  static const rose400 = Color(0xFFFB7185);
  static const rose700 = Color(0xFFBE123C);

  static const red50 = Color(0xFFFEF2F2);
  static const red500 = Color(0xFFEF4444);
  static const red600 = Color(0xFFDC2626);

  // Color map for project cards
  static Color dotColor(String name) {
    switch (name) {
      case 'emerald':
        return emerald400;
      case 'blue':
        return blue400;
      case 'purple':
        return purple400;
      case 'amber':
        return amber400;
      case 'rose':
        return rose400;
      case 'slate':
        return slate400;
      default:
        return emerald400;
    }
  }

  static Color statusBg(String status) {
    switch (status) {
      case '완료':
      case '승인':
        return emerald50;
      case '진행중':
        return purple50;
      case '기획':
        return blue50;
      case '반려':
        return red50;
      case '대기':
        return amber50;
      default:
        return slate100;
    }
  }

  static Color statusText(String status) {
    switch (status) {
      case '완료':
      case '승인':
        return emerald700;
      case '진행중':
        return purple700;
      case '기획':
        return blue700;
      case '반려':
        return red600;
      case '대기':
        return amber700;
      default:
        return slate700;
    }
  }
}

FluentThemeData buildAppTheme() {
  return FluentThemeData(
    fontFamily: 'Pretendard',
    accentColor: AccentColor.swatch({
      'normal': AppColors.primary600,
      'lighter': AppColors.primary500,
      'lightest': AppColors.primary200,
      'dark': AppColors.primary700,
      'darkest': AppColors.primary700,
    }),
    scaffoldBackgroundColor: AppColors.background,
    brightness: Brightness.light,
  );
}
