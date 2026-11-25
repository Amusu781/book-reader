import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// How the whole library looks: the room, the bookcases and the book
/// spines all follow this choice (library settings, top-right gear).
enum LibraryStyle { modern, classic, ancient }

extension LibraryStyleX on LibraryStyle {
  String get label {
    switch (this) {
      case LibraryStyle.modern:
        return 'Modern';
      case LibraryStyle.classic:
        return 'Classic';
      case LibraryStyle.ancient:
        return 'Ancient';
    }
  }

  String get description {
    switch (this) {
      case LibraryStyle.modern:
        return 'Light oak cases, bright cloth spines, a calm modern room';
      case LibraryStyle.classic:
        return 'Walnut bookcases, leather spines with gold bands';
      case LibraryStyle.ancient:
        return 'Old stone-and-timber hall, worn cracked leather, gilded bands';
    }
  }

  /// Bookcase wood: [light face, mid, dark inner shadow].
  List<Color> get wood {
    switch (this) {
      case LibraryStyle.modern:
        return const [Color(0xFFC9A77C), Color(0xFFAE8A5E), Color(0xFF6E5236)];
      case LibraryStyle.classic:
        return const [Color(0xFF7A4E2D), Color(0xFF5C3A20), Color(0xFF2A1A0E)];
      case LibraryStyle.ancient:
        return const [Color(0xFF5A4632), Color(0xFF41321F), Color(0xFF1C140B)];
    }
  }

  /// Spine colours (picked per book from a hash of its title).
  List<Color> get spinePalette {
    switch (this) {
      case LibraryStyle.modern:
        return const [
          Color(0xFF1F6F8B),
          Color(0xFFE07A5F),
          Color(0xFF3D405B),
          Color(0xFF81B29A),
          Color(0xFFF2CC8F),
          Color(0xFF9C2C3F),
          Color(0xFF264653),
          Color(0xFF2A9D8F),
          Color(0xFFE9C46A),
          Color(0xFF6D597A),
        ];
      case LibraryStyle.classic:
        return const [
          Color(0xFF7B1E1E),
          Color(0xFF1E3D2F),
          Color(0xFF1B2A4A),
          Color(0xFF5B2333),
          Color(0xFF6B4423),
          Color(0xFF2F4F4F),
          Color(0xFF4A1C40),
          Color(0xFF8A5A19),
          Color(0xFF233D4D),
          Color(0xFF3B2416),
        ];
      case LibraryStyle.ancient:
        return const [
          Color(0xFF5E3A1E),
          Color(0xFF4B2E19),
          Color(0xFF6E4B2A),
          Color(0xFF3F2A1C),
          Color(0xFF5A2E22),
          Color(0xFF4D3B22),
          Color(0xFF66402A),
          Color(0xFF3A2F1F),
        ];
    }
  }

  Color get gold {
    switch (this) {
      case LibraryStyle.modern:
        return const Color(0xFFF4F1EA); // modern: white/silver foil
      case LibraryStyle.classic:
        return const Color(0xFFD9B04C);
      case LibraryStyle.ancient:
        return const Color(0xFFB8913A);
    }
  }
}

/// How the library groups its bookcases.
enum LibraryGrouping { shelves, series, genre }

extension LibraryGroupingX on LibraryGrouping {
  String get label {
    switch (this) {
      case LibraryGrouping.shelves:
        return 'My shelves';
      case LibraryGrouping.series:
        return 'By series';
      case LibraryGrouping.genre:
        return 'By genre';
    }
  }
}

/// App-wide preferences (library look, grouping, Focus Mode default,
/// first-launch onboarding). Persisted in SharedPreferences, offline.
class AppPrefs extends ChangeNotifier {
  static const _styleKey = 'library_style_v3';
  static const _groupKey = 'library_grouping_v3';
  static const _focusKey = 'focus_mode_default_v3';
  static const _onboardedKey = 'focus_onboarding_done_v3';

  LibraryStyle style = LibraryStyle.classic;
  LibraryGrouping grouping = LibraryGrouping.shelves;

  /// Focus Mode switches itself on whenever a book is opened.
  bool focusModeDefault = false;

  /// The first-launch Focus Mode prompt has been answered.
  bool focusOnboardingDone = false;

  bool loaded = false;

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    style = LibraryStyle.values.firstWhere(
      (s) => s.name == p.getString(_styleKey),
      orElse: () => LibraryStyle.classic,
    );
    grouping = LibraryGrouping.values.firstWhere(
      (g) => g.name == p.getString(_groupKey),
      orElse: () => LibraryGrouping.shelves,
    );
    focusModeDefault = p.getBool(_focusKey) ?? false;
    focusOnboardingDone = p.getBool(_onboardedKey) ?? false;
    loaded = true;
    notifyListeners();
  }

  Future<void> _save() async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_styleKey, style.name);
    await p.setString(_groupKey, grouping.name);
    await p.setBool(_focusKey, focusModeDefault);
    await p.setBool(_onboardedKey, focusOnboardingDone);
  }

  Future<void> setStyle(LibraryStyle s) async {
    style = s;
    notifyListeners();
    await _save();
  }

  Future<void> setGrouping(LibraryGrouping g) async {
    grouping = g;
    notifyListeners();
    await _save();
  }

  Future<void> setFocusModeDefault(bool on) async {
    focusModeDefault = on;
    notifyListeners();
    await _save();
  }

  Future<void> completeFocusOnboarding({required bool focusOn}) async {
    focusOnboardingDone = true;
    focusModeDefault = focusOn;
    notifyListeners();
    await _save();
  }
}
