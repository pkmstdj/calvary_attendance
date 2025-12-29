import 'package:flutter/material.dart';
import 'app_theme.dart';

class ThemeProvider with ChangeNotifier {
  ThemeData _userTheme;
  ThemeData _adminTheme;
  bool _isLoading = true;

  ThemeProvider()
      : _userTheme = createThemeData(Colors.white),
        _adminTheme = createThemeData(Colors.grey) {
    loadThemes();
  }

  ThemeData get userTheme => _userTheme;
  ThemeData get adminTheme => _adminTheme;
  bool get isLoading => _isLoading;

  Future<void> loadThemes() async {
    final (userTheme, adminTheme) = await getThemesFromFirestore();
    _userTheme = userTheme;
    _adminTheme = adminTheme;
    _isLoading = false;
    notifyListeners();
  }
}
