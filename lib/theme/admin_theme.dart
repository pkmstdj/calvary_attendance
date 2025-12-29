
import 'package:flutter/material.dart';

class AdminTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.white30,
      ),
      scaffoldBackgroundColor: const Color(0xFFE3F2FD),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white24, // 진한 파란색
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white54, // 버튼 파란색
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
        ),
      ),
      cardTheme: const CardThemeData(
        color: Colors.white,
        elevation: 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(
            Radius.circular(12),
          ),
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: Colors.white12, // 선택된 아이콘 색
        unselectedItemColor: Colors.grey,     // 선택 안 된 아이콘 색
        type: BottomNavigationBarType.fixed,
        showSelectedLabels: false,
        showUnselectedLabels: false,
      ),
    );
  }
}
