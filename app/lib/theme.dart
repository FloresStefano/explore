import 'package:flutter/material.dart';

import 'common.dart';

/// The app's single theme: Plus Jakarta Sans, the blue palette and the shared component styles.
/// Widgets take sizes, colours and shapes from here and from the tokens in common.dart.
ThemeData appTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: indigo,
    primary: indigo,
    onPrimary: Colors.white,
    secondary: navy,
    surface: Colors.white,
    onSurface: ink,
    onSurfaceVariant: muted,
    outline: border,
    outlineVariant: border,
    error: const Color(0xFFC62828),
  );
  const text = TextTheme(
    displaySmall: TextStyle(fontSize: Fs.display, fontWeight: FontWeight.w800, height: 1.15, letterSpacing: -0.6),
    headlineSmall: TextStyle(fontSize: Fs.headline, fontWeight: FontWeight.w700, height: 1.2, letterSpacing: -0.3),
    titleLarge: TextStyle(fontSize: Fs.titleLg, fontWeight: FontWeight.w700, height: 1.25),
    titleMedium: TextStyle(fontSize: Fs.title, fontWeight: FontWeight.w700, height: 1.3),
    titleSmall: TextStyle(fontSize: Fs.body, fontWeight: FontWeight.w600, height: 1.3),
    bodyLarge: TextStyle(fontSize: Fs.title, fontWeight: FontWeight.w400, height: 1.5),
    bodyMedium: TextStyle(fontSize: Fs.body, fontWeight: FontWeight.w400, height: 1.45),
    bodySmall: TextStyle(fontSize: Fs.small, fontWeight: FontWeight.w400, height: 1.4, color: muted),
    labelLarge: TextStyle(fontSize: Fs.body, fontWeight: FontWeight.w600),
    labelMedium: TextStyle(fontSize: Fs.label, fontWeight: FontWeight.w600),
    labelSmall: TextStyle(fontSize: Fs.caption, fontWeight: FontWeight.w600, letterSpacing: 0.2),
  );
  final base = ThemeData(useMaterial3: true, colorScheme: scheme, fontFamily: 'Jakarta');
  final buttonShape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(Rd.md));
  return base.copyWith(
    scaffoldBackgroundColor: pageBg,
    textTheme: base.textTheme.merge(text).apply(bodyColor: ink, displayColor: ink, fontFamily: 'Jakarta'),
    splashFactory: InkSparkle.splashFactory,
    dividerTheme: const DividerThemeData(color: border, thickness: 1, space: 1),
    iconTheme: const IconThemeData(color: muted, size: 20),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 48),
        padding: const EdgeInsets.symmetric(horizontal: Sp.xl, vertical: Sp.md),
        shape: buttonShape,
        textStyle: const TextStyle(fontFamily: 'Jakarta', fontSize: Fs.body, fontWeight: FontWeight.w700),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(48, 44),
        shape: buttonShape,
        side: const BorderSide(color: border),
        foregroundColor: indigo,
        textStyle: const TextStyle(fontFamily: 'Jakarta', fontSize: Fs.body, fontWeight: FontWeight.w600),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        shape: buttonShape,
        foregroundColor: indigo,
        textStyle: const TextStyle(fontFamily: 'Jakarta', fontSize: Fs.body, fontWeight: FontWeight.w600),
      ),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 6,
      shadowColor: navy.withValues(alpha: 0.25),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Rd.lg)),
      textStyle: const TextStyle(fontFamily: 'Jakarta', fontSize: Fs.body, color: ink),
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(color: navy, borderRadius: BorderRadius.circular(Rd.sm)),
      textStyle: const TextStyle(fontFamily: 'Jakarta', fontSize: Fs.label, color: Colors.white),
      waitDuration: const Duration(milliseconds: 400),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: navy,
      contentTextStyle: const TextStyle(fontFamily: 'Jakarta', fontSize: Fs.body, color: Colors.white),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Rd.md)),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      height: 68,
      indicatorColor: const Color(0xFFE3E9FB),
      indicatorShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(99)),
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      iconTheme: WidgetStateProperty.resolveWith((s) =>
          IconThemeData(size: 22, color: s.contains(WidgetState.selected) ? indigo : muted)),
      labelTextStyle: WidgetStateProperty.resolveWith((s) => TextStyle(
            fontFamily: 'Jakarta',
            fontSize: Fs.caption,
            fontWeight: s.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w500,
            color: s.contains(WidgetState.selected) ? indigo : muted,
          )),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(color: indigo, linearTrackColor: chipBg),
    // Material 3 motion on every platform, web included: fade forwards between pages.
    pageTransitionsTheme: const PageTransitionsTheme(builders: {
      TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
      TargetPlatform.iOS: FadeForwardsPageTransitionsBuilder(),
      TargetPlatform.macOS: FadeForwardsPageTransitionsBuilder(),
      TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
      TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
      TargetPlatform.fuchsia: FadeForwardsPageTransitionsBuilder(),
    }),
  );
}
