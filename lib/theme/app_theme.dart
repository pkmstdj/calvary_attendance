import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// Hex 문자열 (예: "FFFFFF")을 Color 객체로 변환합니다.
Color _colorFromHex(String hexString) {
  final buffer = StringBuffer();
  if (hexString.length == 6 || hexString.length == 7) buffer.write('ff');
  buffer.write(hexString.replaceFirst('#', ''));
  try {
    return Color(int.parse(buffer.toString(), radix: 16));
  } catch (e) {
    // 파싱 오류 시 안전한 기본 색상 반환
    return Colors.grey;
  }
}

/// 색상의 밝기에 따라 적절한 전경색(흰색 또는 검은색)을 반환합니다.
Color _foregroundColorFor(Color color) {
  return ThemeData.estimateBrightnessForColor(color) == Brightness.dark
      ? Colors.white
      : Colors.black;
}

/// 단일 시드 색상으로부터 ThemeData를 생성합니다.
ThemeData createThemeData(Color seedColor) {
  final colorScheme = ColorScheme.fromSeed(
    seedColor: seedColor,
    brightness: Brightness.light,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: colorScheme.background,
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
      elevation: 1,
      color: colorScheme.surface,
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
      backgroundColor: colorScheme.secondaryContainer,
      selectedColor: colorScheme.primary,
    ),
  );
}

/// Firestore에서 테마 정보를 가져와 사용자 및 관리자 테마를 반환합니다.
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

    String userColorHex = 'FFFFFF'; // 기본 흰색
    if (data['color'] is String) {
      userColorHex = data['color'];
    }

    String adminColorHex = '808080'; // 기본 회색
    if (data['admin'] is String) {
      adminColorHex = data['admin'];
    }

    final userColor = _colorFromHex(userColorHex); 
    final adminColor = _colorFromHex(adminColorHex);

    return (createThemeData(userColor), createThemeData(adminColor));
  } catch (e) {
    debugPrint("오류: Firestore에서 테마 정보를 가져오는 중 예외가 발생했습니다: $e");
    return (createThemeData(Colors.white), createThemeData(Colors.grey));
  }
}
