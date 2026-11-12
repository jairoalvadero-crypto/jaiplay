import 'package:flutter/material.dart';

const kBg = Color(0xFF000000);
const kCard = Color(0xFF1C1C1E);
const kAccent = Color(0xFFFA2D48);
const kMuted = Color(0xFF8E8E93);

const kTitle = TextStyle(fontSize: 30, fontWeight: FontWeight.w800);
const kH2 = TextStyle(fontSize: 20, fontWeight: FontWeight.w700);

ThemeData buildTheme() {
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: kBg,
    colorScheme: const ColorScheme.dark(primary: kAccent, surface: kBg),
    splashFactory: NoSplash.splashFactory,
    appBarTheme: const AppBarTheme(
      backgroundColor: kBg,
      elevation: 0,
      scrolledUnderElevation: 0,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: const Color(0xFF0B0B0C),
      indicatorColor: Colors.transparent,
      height: 64,
      iconTheme: WidgetStateProperty.resolveWith(
        (s) => IconThemeData(
          color: s.contains(WidgetState.selected) ? kAccent : kMuted,
        ),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (s) => TextStyle(
          fontSize: 11,
          color: s.contains(WidgetState.selected) ? kAccent : kMuted,
        ),
      ),
    ),
    navigationRailTheme: const NavigationRailThemeData(
      indicatorColor: Color(0x33FA2D48),
      selectedIconTheme: IconThemeData(color: kAccent),
      unselectedIconTheme: IconThemeData(color: kMuted),
      selectedLabelTextStyle: TextStyle(color: kAccent),
      unselectedLabelTextStyle: TextStyle(color: kMuted),
    ),
    sliderTheme: SliderThemeData(
      trackHeight: 6,
      activeTrackColor: Colors.white,
      inactiveTrackColor: Colors.white24,
      thumbColor: Colors.white,
      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
      overlayColor: const Color.fromRGBO(255, 255, 255, 0.16),
      overlayShape: const RoundSliderOverlayShape(overlayRadius: 18),
    ),
  );
}
