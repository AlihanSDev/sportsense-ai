import 'package:flutter/material.dart';

enum AppTheme {
  light,
  dark,
  sportsense,
}

class ThemeNotifier extends ChangeNotifier {
  AppTheme _theme = AppTheme.sportsense;

  AppTheme get theme => _theme;

  ThemeMode get mode {
    switch (_theme) {
      case AppTheme.light:
        return ThemeMode.light;
      case AppTheme.dark:
      case AppTheme.sportsense:
        return ThemeMode.dark;
    }
  }

  bool get isDark => _theme != AppTheme.light;

  void setTheme(AppTheme theme) {
    if (_theme == theme) return;
    _theme = theme;
    notifyListeners();
  }
}

final themeNotifier = ThemeNotifier();
