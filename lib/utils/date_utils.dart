import 'package:cloud_firestore/cloud_firestore.dart';

// lib/utils/date_utils.dart

/// 화면에 보여줄 때 쓰는 생년월일 포맷터
/// - 숫자만 8자리(yyyyMMdd)면 yyyy-MM-dd로 바꿔서 리턴
/// - 그 외에는 원본 그대로 리턴
String formatBirthDate(String raw) {
  if (raw.isEmpty) return '';
  final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.length != 8) {
    return raw;
  }
  final y = digits.substring(0, 4);
  final m = digits.substring(4, 6);
  final d = digits.substring(6, 8);
  return '$y-$m-$d';
}

/// Timestamp를 'yyyy-MM-dd HH:mm' 형식의 문자열로 변환합니다.
String formatDateTime(Timestamp ts) {
  final dt = ts.toDate();
  final y = dt.year.toString();
  final m = dt.month.toString().padLeft(2, '0');
  final d = dt.day.toString().padLeft(2, '0');
  final h = dt.hour.toString().padLeft(2, '0');
  final min = dt.minute.toString().padLeft(2, '0');
  return '$y-$m-$d $h:$min';
}
