import 'package:cloud_firestore/cloud_firestore.dart';

/// 출생연도를 기준으로 기수를 계산합니다. (1992년생 = 30기)
/// 공식: 기수 = 출생연도 - 1962
int calculateGisu(int birthYear) {
  return birthYear - 1962;
}

/// 출생연도를 기준으로 현재 나이를 계산하고, 대그룹을 반환합니다.
/// 1청: 20-25세, 2청: 26-29세, 3청: 30-39세
String calculateYouthGroup(int birthYear) {
  final currentYear = DateTime.now().year;
  final age = currentYear - birthYear + 1;

  if (age >= 20 && age <= 25) {
    return '1청';
  } else if (age >= 26 && age <= 29) {
    return '2청';
  } else if (age >= 30 && age <= 39) {
    return '3청';
  } else {
    return '기타'; // 해당 범위 밖
  }
}

/// 모든 사용자의 gisu와 youthGroup 필드를 업데이트하는 스크립트.
/// 필요 시 관리자 기능으로 호출할 수 있습니다.
Future<void> updateUserGroupsAndGisu() async {
  final usersRef = FirebaseFirestore.instance.collection('users');
  final snapshot = await usersRef.get();

  final batch = FirebaseFirestore.instance.batch();

  for (final doc in snapshot.docs) {
    final data = doc.data();
    final birthDateRaw = data['birthDate'] as String?;
    
    if (birthDateRaw != null && birthDateRaw.length >= 4) {
      final birthYear = int.tryParse(birthDateRaw.substring(0, 4));
      if (birthYear != null) {
        final gisu = calculateGisu(birthYear);
        final youthGroup = calculateYouthGroup(birthYear);
        
        batch.update(doc.reference, {
          'gisu': gisu,
          'youthGroup': youthGroup,
        });
      }
    }
  }
  
  await batch.commit();
}

/// 권한 레벨에 따른 한글 라벨을 반환합니다.
String getPermissionLabel(int level) {
  switch (level) {
    case 0:
      return '사역자';
    case 1:
      return '청장';
    case 2:
      return '리더';
    case 3:
      return '청년';
    case 4:
      return '미승인';
    default:
      return '알 수 없음';
  }
}
