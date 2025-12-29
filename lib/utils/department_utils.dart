class DepartmentCalculator {
  // 생년월일(예: "1998-01-01")을 기반으로 소속을 계산합니다.
  // 20-25세: 1청, 26-29세: 2청, 30-39세: 3청
  static String calculateDepartment(String? birthDate) {
    if (birthDate == null || birthDate.length < 4) {
      return ''; // 정보가 없으면 계산하지 않음
    }

    final year = int.tryParse(birthDate.substring(0, 4));
    if (year == null) {
      return '';
    }

    // 한국 나이로 계산 (현재 연도 - 출생 연도 + 1)
    final currentYear = DateTime.now().year;
    final age = currentYear - year + 1;

    if (age >= 20 && age <= 25) {
      return '1청';
    } else if (age >= 26 && age <= 29) {
      return '2청';
    } else if (age >= 30 && age <= 39) {
      return '3청';
    } else {
      // 그 외 나이대는 자동으로 지정하지 않음
      return '';
    }
  }
}
