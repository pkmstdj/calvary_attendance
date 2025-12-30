/// 사용자의 권한 레벨(숫자)을 사람이 읽을 수 있는 문자열로 변환합니다.
String getPermissionLabel(int? level) {
  switch (level) {
    case 0:
      return '사역자';
    case 1:
      return '청장'; // '팀장'에서 '청장'으로 수정
    case 2:
      return '리더';
    case 3:
      return '청년';
    case 4:
      return '승인 대기';
    default:
      return '알 수 없음';
  }
}
