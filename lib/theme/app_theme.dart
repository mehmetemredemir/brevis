import 'package:flutter/material.dart';

/// Işık/karanlık arasında değişen tüm renkleri buradan oku — doğrudan
/// AppColors.* veya AppColorsDark.* KULLANMA (o zaman dark mode'da donuk kalır).
/// Örnek: `final palette = AppPalette.of(context); palette.surface`
class AppPalette {
  const AppPalette({
    required this.ink,
    required this.inkMuted,
    required this.paper,
    required this.surface,
    required this.slate,
    required this.slateDeep,
    required this.amber,
    required this.hairline,
    required this.danger,
  });

  final Color ink;
  final Color inkMuted;
  final Color paper;
  final Color surface;
  final Color slate;
  final Color slateDeep;
  final Color amber;
  final Color hairline;
  final Color danger;

  static const light = AppPalette(
    ink: AppColors.ink,
    inkMuted: AppColors.inkMuted,
    paper: AppColors.paper,
    surface: AppColors.surface,
    slate: AppColors.slate,
    slateDeep: AppColors.slateDeep,
    amber: AppColors.amber,
    hairline: AppColors.hairline,
    danger: AppColors.danger,
  );

  static const dark = AppPalette(
    ink: AppColorsDark.ink,
    inkMuted: AppColorsDark.inkMuted,
    paper: AppColorsDark.paper,
    surface: AppColorsDark.surface,
    slate: AppColorsDark.slate,
    slateDeep: AppColorsDark.slateDeep,
    amber: AppColorsDark.amber,
    hairline: AppColorsDark.hairline,
    danger: AppColorsDark.danger,
  );

  static AppPalette of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? dark : light;
}

/// Tasarım kararı: bu bir "bildirim gürültüsünü azalt" uygulaması, o yüzden
/// paleti de görsel olarak GÜRÜLTÜSÜZ olmalı. Jenerik Material mor/indigo'dan
/// ve klişe "warm cream + terracotta" kombinasyonundan bilinçli olarak kaçındık.
///
/// Palet:
///   ink      #171B1F  — birincil metin
///   paper    #F6F5F1  — arka plan (saf beyaz değil, hafif kağıt tonu)
///   surface  #FCFBF8  — liste satırı / input yüzeyi
///   slate    #3F6C74  — birincil aksan (sakin çamurlu-teal — "sessizleştirme" hissi)
///   amber    #C98A2C  — ikincil aksan, sadece "önemli kelime" gibi dikkat
///                        gerektiren tek noktalarda kullanılır
///   hairline #E4E1D8  — bölücü çizgiler (gölge yerine)
class AppColors {
  static const ink = Color(0xFF171B1F);
  static const inkMuted = Color(0xFF5B6167);
  static const paper = Color(0xFFF6F5F1);
  static const surface = Color(0xFFFCFBF8);
  static const slate = Color(0xFF3F6C74);
  static const slateDeep = Color(0xFF2C4E54);
  static const amber = Color(0xFFC98A2C);
  static const hairline = Color(0xFFE4E1D8);
  static const danger = Color(0xFFB3543F);
}

/// Karanlık mod paleti — ink/paper'ı ters çevirip kontrastı yeniden ayarladık,
/// slate aksanını koyu zeminde okunur kalsın diye biraz açtık.
class AppColorsDark {
  static const ink = Color(0xFFECEAE4);
  static const inkMuted = Color(0xFF9DA3A8);
  static const paper = Color(0xFF15181B);
  static const surface = Color(0xFF1D2124);
  static const slate = Color(0xFF6FA8B0);
  static const slateDeep = Color(0xFF8FC0C7);
  static const amber = Color(0xFFD9A24C);
  static const hairline = Color(0xFF2C3134);
  static const danger = Color(0xFFE0876D);
}

class AppTheme {
  static ThemeData light() => _build(colors: AppPalette.light, brightness: Brightness.light);

  static ThemeData dark() => _build(colors: AppPalette.dark, brightness: Brightness.dark);

  static ThemeData _build({required AppPalette colors, required Brightness brightness}) {
    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: ColorScheme.fromSeed(
        seedColor: colors.slate,
        brightness: brightness,
        primary: colors.slate,
        surface: colors.surface,
      ),
      scaffoldBackgroundColor: colors.paper,
      fontFamily: 'Roboto',
    );

    return base.copyWith(
      textTheme: base.textTheme.copyWith(
        headlineSmall: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.3,
          color: colors.ink,
        ),
        titleMedium: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: colors.ink,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          height: 1.4,
          color: colors.inkMuted,
        ),
        labelLarge: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.1,
          color: colors.inkMuted,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: colors.paper,
        foregroundColor: colors.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: colors.ink,
          letterSpacing: -0.2,
        ),
      ),
      listTileTheme: ListTileThemeData(
        tileColor: colors.surface,
        iconColor: colors.slate,
        textColor: colors.ink,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.selected) ? colors.slate : Colors.white,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? colors.slate.withValues(alpha: 0.4)
              : colors.hairline,
        ),
      ),
      dividerTheme: DividerThemeData(
        color: colors.hairline,
        thickness: 1,
        space: 1,
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: colors.surface,
        side: BorderSide(color: colors.hairline),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        labelStyle: TextStyle(color: colors.ink, fontSize: 13),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: colors.hairline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: colors.hairline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: colors.slate, width: 1.4),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colors.slate,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
