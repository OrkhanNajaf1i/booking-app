import 'package:flutter/material.dart';

/// Tətbiqin vizual dili.
///
/// Rənglər admin panelin `index.css`-indəki tokenlərlə eynidir — eyni
/// məhsulun iki üzü fərqli görünməməlidir.
///
/// Əvvəl `ColorScheme.fromSeed` işlədilirdi: o, toxumdan bütün tonları
/// özü uydururdu və nəticədə kartlar sönük mavi-boz çalarlarla
/// növbələşirdi. İndi tonlar açıq yazılır.
class AppPalette {
  const AppPalette._();

  // ── Marka ───────────────────────────────────────────────────
  // brand-700: ağ fonda 5.47:1, üzərində ağ mətn də 5.47:1 — hər
  // ikisi WCAG AA keçir.
  static const brand50 = Color(0xFFF0FDFA);
  static const brand100 = Color(0xFFCCFBF1);
  static const brand200 = Color(0xFF99F6E4);
  static const brand400 = Color(0xFF2DD4BF);
  static const brand600 = Color(0xFF0D9488);
  static const brand700 = Color(0xFF0F766E);
  static const brand800 = Color(0xFF115E59);
  static const brand900 = Color(0xFF134E4A);

  // ── Boz ─────────────────────────────────────────────────────
  static const slate50 = Color(0xFFF8FAFC);
  static const slate100 = Color(0xFFF1F5F9);
  static const slate200 = Color(0xFFE2E8F0);
  static const slate300 = Color(0xFFCBD5E1);
  static const slate400 = Color(0xFF94A3B8);
  static const slate500 = Color(0xFF64748B);
  static const slate600 = Color(0xFF475569);
  static const slate800 = Color(0xFF1E293B);
  static const slate900 = Color(0xFF0F172A);

  // ── Status ──────────────────────────────────────────────────
  static const success = Color(0xFF047857);
  static const successBg = Color(0xFFECFDF5);
  static const warning = Color(0xFFB45309);
  static const warningBg = Color(0xFFFFFBEB);
  static const danger = Color(0xFFBE123C);
  static const dangerBg = Color(0xFFFFF1F2);
  static const info = Color(0xFF0369A1);
  static const infoBg = Color(0xFFF0F9FF);
}

/// Radiuslar bir yerdə — hər ekran öz rəqəmini uydurmasın.
class AppRadius {
  const AppRadius._();

  static const double field = 12;
  static const double card = 14;
  static const double sheet = 20;
  static const double pill = 999;
}

class AppTheme {
  const AppTheme._();

  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isLight = brightness == Brightness.light;

    final scheme = isLight
        ? const ColorScheme.light(
            primary: AppPalette.brand700,
            onPrimary: Colors.white,
            primaryContainer: AppPalette.brand50,
            onPrimaryContainer: AppPalette.brand800,
            secondary: AppPalette.brand600,
            onSecondary: Colors.white,
            secondaryContainer: AppPalette.brand100,
            onSecondaryContainer: AppPalette.brand900,
            surface: Colors.white,
            onSurface: AppPalette.slate900,
            onSurfaceVariant: AppPalette.slate500,
            surfaceContainerLowest: Colors.white,
            surfaceContainerLow: AppPalette.slate50,
            surfaceContainer: AppPalette.slate50,
            surfaceContainerHigh: AppPalette.slate100,
            surfaceContainerHighest: AppPalette.slate100,
            outline: AppPalette.slate400,
            outlineVariant: AppPalette.slate200,
            error: AppPalette.danger,
            onError: Colors.white,
            errorContainer: AppPalette.dangerBg,
            onErrorContainer: AppPalette.danger,
          )
        : const ColorScheme.dark(
            // Tünd fonda brand-700 sönük qalır; bir pillə açılır.
            primary: AppPalette.brand400,
            onPrimary: Color(0xFF042F2E),
            primaryContainer: AppPalette.brand900,
            onPrimaryContainer: AppPalette.brand100,
            secondary: AppPalette.brand400,
            onSecondary: Color(0xFF042F2E),
            secondaryContainer: AppPalette.brand900,
            onSecondaryContainer: AppPalette.brand100,
            surface: Color(0xFF111A2B),
            onSurface: Color(0xFFF1F5F9),
            onSurfaceVariant: AppPalette.slate400,
            surfaceContainerLowest: Color(0xFF0B1220),
            surfaceContainerLow: Color(0xFF111A2B),
            surfaceContainer: Color(0xFF162031),
            surfaceContainerHigh: AppPalette.slate800,
            surfaceContainerHighest: AppPalette.slate800,
            outline: AppPalette.slate600,
            outlineVariant: AppPalette.slate800,
            error: Color(0xFFFB7185),
            onError: Color(0xFF4C0519),
          );

    final baseText = isLight ? AppPalette.slate900 : const Color(0xFFF1F5F9);
    final mutedText = isLight ? AppPalette.slate500 : AppPalette.slate400;

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      fontFamily: 'Inter',
      scaffoldBackgroundColor: isLight
          ? AppPalette.slate50
          : const Color(0xFF0B1220),

      // Material 3 səthlərə marka rəngindən çalar qatır; kartların
      // növbələşən çalarları məhz bundan idi.
      splashFactory: InkSparkle.splashFactory,

      textTheme: _textTheme(baseText, mutedText),

      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        foregroundColor: baseText,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: 'Inter',
          color: baseText,
          fontSize: 19,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
        shape: Border(
          bottom: BorderSide(color: scheme.outlineVariant, width: 1),
        ),
      ),

      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: scheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isLight ? Colors.white : const Color(0xFF162031),
        hintStyle: TextStyle(color: mutedText, fontSize: 15),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.field),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.field),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        // Fokus görünən olmalıdır — klaviatura ilə gəzən istifadəçi
        // harada olduğunu bilməlidir.
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.field),
          borderSide: BorderSide(color: scheme.primary, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.field),
          borderSide: BorderSide(color: scheme.error),
        ),
        prefixIconColor: mutedText,
        suffixIconColor: mutedText,
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(50),
          textStyle: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.field),
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
          side: BorderSide(color: scheme.outlineVariant),
          foregroundColor: baseText,
          textStyle: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.field),
          ),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: scheme.primary,
          textStyle: const TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      chipTheme: ChipThemeData(
        backgroundColor: isLight ? AppPalette.slate100 : AppPalette.slate800,
        selectedColor: scheme.primaryContainer,
        side: BorderSide.none,
        labelStyle: TextStyle(
          fontFamily: 'Inter',
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: baseText,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
      ),

      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: scheme.primaryContainer,
        elevation: 0,
        height: 68,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontFamily: 'Inter',
            fontSize: 12,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w600
                : FontWeight.w500,
            color: states.contains(WidgetState.selected) ? baseText : mutedText,
          ),
        ),
      ),

      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        thickness: 1,
        space: 1,
      ),

      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.sheet),
          ),
        ),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sheet),
        ),
      ),

      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppPalette.slate900,
        contentTextStyle: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 14,
          color: Colors.white,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.field),
        ),
      ),

      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        strokeWidth: 2.5,
      ),
    );
  }

  /// Mətn ölçüləri — başlıq böyüdükcə hərflər arası boşluq sıxılır,
  /// əks halda iri mətn dağınıq görünür.
  static TextTheme _textTheme(Color base, Color muted) {
    return TextTheme(
      headlineSmall: TextStyle(
        fontSize: 23,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.4,
        color: base,
      ),
      titleLarge: TextStyle(
        fontSize: 19,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
        color: base,
      ),
      titleMedium: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.1,
        color: base,
      ),
      titleSmall: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: base,
      ),
      bodyLarge: TextStyle(fontSize: 15, height: 1.45, color: base),
      bodyMedium: TextStyle(fontSize: 14, height: 1.45, color: base),
      bodySmall: TextStyle(fontSize: 13, height: 1.4, color: muted),
      labelLarge: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: base,
      ),
      labelMedium: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: muted,
      ),
      labelSmall: TextStyle(
        fontSize: 11.5,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.2,
        color: muted,
      ),
    );
  }

  /// Bron statusuna uyğun rəng — mətn üçün.
  static Color statusColor(ColorScheme scheme, String status) {
    switch (status) {
      case 'pending':
        return AppPalette.warning;
      case 'confirmed':
        return AppPalette.success;
      case 'reschedule_proposed':
        return AppPalette.info;
      case 'cancelled':
      case 'no_show':
        return AppPalette.danger;
      default:
        return scheme.onSurfaceVariant;
    }
  }

  /// Həmin statusun açıq fon rəngi — nişan üçün.
  static Color statusBackground(ColorScheme scheme, String status) {
    switch (status) {
      case 'pending':
        return AppPalette.warningBg;
      case 'confirmed':
        return AppPalette.successBg;
      case 'reschedule_proposed':
        return AppPalette.infoBg;
      case 'cancelled':
      case 'no_show':
        return AppPalette.dangerBg;
      default:
        return scheme.surfaceContainerHigh;
    }
  }
}
