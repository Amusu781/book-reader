import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum PageTheme { crisp, frayed, ancient }

extension PageThemeX on PageTheme {
  String get label {
    switch (this) {
      case PageTheme.crisp:
        return 'Crisp';
      case PageTheme.frayed:
        return 'Frayed';
      case PageTheme.ancient:
        return 'Ancient';
    }
  }

  String get description {
    switch (this) {
      case PageTheme.crisp:
        return 'Clean white pages, sharp text';
      case PageTheme.frayed:
        return 'Worn off-white paper, classic serif';
      case PageTheme.ancient:
        return 'Dark parchment, old-style type';
    }
  }

  Color get background {
    switch (this) {
      case PageTheme.crisp:
        return const Color(0xFFFFFFFF);
      case PageTheme.frayed:
        return const Color(0xFFF3EAD3);
      case PageTheme.ancient:
        return const Color(0xFFE8D5A8);
    }
  }

  Color get textColor {
    switch (this) {
      case PageTheme.crisp:
        return const Color(0xFF1A1A1A);
      case PageTheme.frayed:
        return const Color(0xFF3B2F23);
      case PageTheme.ancient:
        return const Color(0xFF2E1F0E);
    }
  }

  String get fontFamily {
    // Flutter ships with serif/sans fallbacks; these are family names
    // resolved by the platform. 'serif' gives the classic book feel
    // for Frayed/Ancient, sans for Crisp.
    switch (this) {
      case PageTheme.crisp:
        return 'sans-serif';
      case PageTheme.frayed:
      case PageTheme.ancient:
        return 'serif';
    }
  }
}

class ReaderSettings {
  PageTheme theme;
  double fontSize;
  double lineHeight;
  bool nightMode;
  double brightnessDim; // 0.0 (full bright) - 0.5 (dimmed overlay)

  ReaderSettings({
    this.theme = PageTheme.frayed,
    this.fontSize = 18,
    this.lineHeight = 1.6,
    this.nightMode = false,
    this.brightnessDim = 0,
  });

  Color get background =>
      nightMode ? const Color(0xFF121212) : theme.background;
  Color get textColor => nightMode ? const Color(0xFFE8E0D0) : theme.textColor;

  static const _themeKey = 'reader_theme';
  static const _fontSizeKey = 'reader_font_size';
  static const _lineHeightKey = 'reader_line_height';
  static const _nightModeKey = 'reader_night_mode';
  static const _brightnessKey = 'reader_brightness_dim';

  /// Load the saved settings (shared across every book and session).
  static Future<ReaderSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    final themeName = prefs.getString(_themeKey);
    final theme = PageTheme.values.firstWhere(
      (t) => t.name == themeName,
      orElse: () => PageTheme.frayed,
    );
    return ReaderSettings(
      theme: theme,
      fontSize: (prefs.getDouble(_fontSizeKey) ?? 18).clamp(14, 26),
      lineHeight: (prefs.getDouble(_lineHeightKey) ?? 1.6).clamp(1.2, 2.0),
      nightMode: prefs.getBool(_nightModeKey) ?? false,
      brightnessDim: (prefs.getDouble(_brightnessKey) ?? 0).clamp(0, 0.5),
    );
  }

  /// Persist the current settings so they stick across books and sessions.
  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeKey, theme.name);
    await prefs.setDouble(_fontSizeKey, fontSize);
    await prefs.setDouble(_lineHeightKey, lineHeight);
    await prefs.setBool(_nightModeKey, nightMode);
    await prefs.setDouble(_brightnessKey, brightnessDim);
  }
}
