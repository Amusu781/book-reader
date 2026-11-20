import 'package:flutter/material.dart';

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
  Color get textColor =>
      nightMode ? const Color(0xFFE8E0D0) : theme.textColor;
}
