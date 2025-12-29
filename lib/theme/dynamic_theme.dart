import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

// Hex 문자열을 Color 객체로 변환
Color _colorFromHex(String hex) {
  final hexCode = hex.replaceAll('#', '');
  return Color(int.parse('FF$hexCode', radix: 16));
}

// 명도에 따라 적절한 전경색(흰색 또는 검은색)을 반환
Color _foregroundColorFor(Color color) {
  return ThemeData.estimateBrightnessForColor(color) == Brightness.dark
      ? Colors.white
      : Colors.black;
}

// 기본 색상을 기반으로 전체 테마 데이터를 생성
ThemeData createThemeData(Color seed) {
  final colorScheme = ColorScheme.fromSeed(
    seedColor: seed,
    brightness: Brightness.light,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: colorScheme.surface.withAlpha(240),
    appBarTheme: AppBarTheme(
      backgroundColor: colorScheme.primary,
      foregroundColor: _foregroundColorFor(colorScheme.primary),
      elevation: 0,
      centerTitle: true,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: colorScheme.primary,
        foregroundColor: _foregroundColorFor(colorScheme.primary),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    ),
    cardTheme: CardThemeData(
      color: colorScheme.surface,
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.all(Radius.circular(12)),
      ),
    ),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: colorScheme.surface,
      selectedItemColor: colorScheme.primary,
      unselectedItemColor: colorScheme.onSurface.withOpacity(0.6),
      type: BottomNavigationBarType.fixed,
      showSelectedLabels: false,
      showUnselectedLabels: false,
    ),
    chipTheme: ChipThemeData(
      backgroundColor: colorScheme.secondaryContainer.withOpacity(0.5),
      selectedColor: colorScheme.primary,
    ),
  );
}

// Firestore에서 테마 정보를 가져와 사용자 및 관리자 테마를 반환
Future<(ThemeData, ThemeData)> getThemesFromFirestore() async {
  try {
    final snapshot = await FirebaseFirestore.instance
        .collection('theme')
        .orderBy(FieldPath.documentId, descending: true)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) {
      return (createThemeData(Colors.white), createThemeData(Colors.grey));
    }

    final data = snapshot.docs.first.data();
    final userColor = _colorFromHex(data['color'] ?? 'FFFFFF'); // Fallback to brown
    final adminColor = _colorFromHex(data['admin'] ?? 'FFFFFF'); // Fallback to blue

    return (createThemeData(userColor), createThemeData(adminColor));
  } catch (e) {
    // 오류 발생 시 기본 폴백 테마 반환
    return (createThemeData(Colors.white), createThemeData(Colors.grey));
  }
}
