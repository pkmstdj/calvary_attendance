class AgeCalculator {
  // 생년월일(예: "1998-01-01")을 기반으로 기수를 계산합니다.
  // 1992년생이 30기인 것을 기준으로 합니다. (출생연도 - 1962)
  static String calculateClassYear(String? birthDate) {
    if (birthDate == null || birthDate.length < 4) {
      return ''; // 생년월일 정보가 없으면 빈 문자열 반환
    }

    // 생년월일에서 연도를 추출
    final year = int.tryParse(birthDate.substring(0, 4));

    if (year == null) {
      return '';
    }

    // 1992년생이 30기인 것을 기준으로 계산 (year - 1962)
    final classYear = year - 1962;

    // 계산된 기수가 0보다 작거나 같으면 빈 문자열 반환 (예외 처리)
    if (classYear <= 0) {
      return '';
    }

    return classYear.toString();
  }
}
