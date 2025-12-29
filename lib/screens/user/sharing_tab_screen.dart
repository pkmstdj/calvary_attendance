import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../utils/date_utils.dart';
import '../prayer/prayer_detail_screen.dart';

class SharingTabScreen extends StatelessWidget {
  final String? currentUserPhoneNumber; // 현재 사용자 전화번호
  final int? currentUserPermissionLevel; // 현재 사용자 권한

  const SharingTabScreen({
    super.key,
    this.currentUserPhoneNumber,
    this.currentUserPermissionLevel,
  });

  @override
  Widget build(BuildContext context) {
    // 현재 사용자 정보가 없으면 로딩 인디케이터 표시
    if (currentUserPhoneNumber == null || currentUserPermissionLevel == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final query = FirebaseFirestore.instance
        .collection('prayerRequests')
        .where('authorPermissionLevel', isLessThanOrEqualTo: currentUserPermissionLevel)
        .orderBy('createdAt', descending: true);

    return SafeArea(
      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: query.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(child: Text('기도제목을 불러오는 중 오류가 발생했습니다.'));
          }

          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return const Center(child: Text('공유된 기도제목이 없습니다.'));
          }

          return ListView.separated(
            itemCount: docs.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data();

              final content = (data['content'] ?? '').toString();
              final createdAt = data['createdAt'] as Timestamp?;
              final authorName = (data['authorName'] ?? '-').toString();
              final authorPhone = (data['phoneNumber'] ?? '').toString();
              final List<dynamic> checkedBy = data['checkedBy'] as List<dynamic>? ?? [];

              final bool isMyPrayer = authorPhone == currentUserPhoneNumber;
              final bool isCheckedByMe = checkedBy.contains(currentUserPhoneNumber);

              // 내가 쓴 기도제목은 목록에 표시하지 않음
              if (isMyPrayer) {
                return const SizedBox.shrink();
              }

              return ListTile(
                title: Text(
                  content,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: isCheckedByMe ? FontWeight.normal : FontWeight.bold,
                  ),
                ),
                subtitle: Text(
                  '$authorName  ${createdAt != null ? formatDateTime(createdAt) : ''}',
                  style: const TextStyle(fontSize: 12),
                ),
                trailing: isCheckedByMe
                    ? const Icon(Icons.check, color: Colors.green, size: 18)
                    : const Icon(Icons.circle, color: Colors.red, size: 10),
                onTap: () {
                  Navigator.pushNamed(
                    context,
                    '/prayerDetail',
                    arguments: PrayerDetailArguments(
                      prayerId: doc.id,
                      viewerPhoneNumber: currentUserPhoneNumber!,
                      viewerPermissionLevel: currentUserPermissionLevel!,
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
