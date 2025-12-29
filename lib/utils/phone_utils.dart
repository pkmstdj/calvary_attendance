String formatPhoneNumber(String raw) {
  final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.length == 10) {
    return '${digits.substring(0, 3)}-'
        '${digits.substring(3, 6)}-'
        '${digits.substring(6)}';
  } else if (digits.length == 11) {
    return '${digits.substring(0, 3)}-'
        '${digits.substring(3, 7)}-'
        '${digits.substring(7)}';
  } else {
    return raw;
  }
}
