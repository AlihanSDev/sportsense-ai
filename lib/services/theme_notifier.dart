import 'package:flutter/material.dart';

/// Тип темы приложения
enum AppTheme { dark, light, sportsense }

/// Нотификатор темы
class ThemeNotifier extends ChangeNotifier {
  AppTheme _theme = AppTheme.dark;
  AppTheme get theme => _theme;
  bool get isDark => _theme == AppTheme.dark;
  bool get isLight => _theme == AppTheme.light;
  bool get isSportsense => _theme == AppTheme.sportsense;
  ThemeMode get mode => _theme == AppTheme.light ? ThemeMode.light : ThemeMode.dark;

  void setTheme(AppTheme theme) {
    if (_theme == theme) return;
    _theme = theme;
    notifyListeners();
  }

  void toggle() {
    if (_theme == AppTheme.dark) {
      _theme = AppTheme.light;
    } else if (_theme == AppTheme.light) {
      _theme = AppTheme.sportsense;
    } else {
      _theme = AppTheme.dark;
    }
    notifyListeners();
  }
}

/// Глобальный экземпляр
final themeNotifier = ThemeNotifier();
