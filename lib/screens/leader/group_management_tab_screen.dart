import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../admin/admin_user_profile_screen.dart';

class GroupManagementTabScreen extends StatelessWidget {
  final String leaderPhoneNumber;

  const GroupManagementTabScreen({
    super.key,
    required this.leaderPhoneNumber,
  });

  @override
  Widget build(BuildContext context) {
    // 사용자의 'leaderId' 필드에 리더의 전화번호가 저장되어 있다고 가정합니다.
    final query = FirebaseFirestore.instance
        .collection('users')
        .where('leaderId', isEqualTo: leaderPhoneNumber)
        .orderBy('name');

    return Scaffold(
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: query.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(child: Text('소그룹 멤버를 불러오는 중 오류가 발생했습니다.'));
          }
          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return const Center(child: Text('소속된 그룹원이 없습니다.'));
          }

          return ListView.separated(
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final member = docs[index].data();
              final memberName = member['name'] ?? '이름 없음';
              final memberPhone = member['phoneNumber'] ?? '';

              return ListTile(
                title: Text(memberName),
                subtitle: Text(memberPhone),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  // 리더의 권한 레벨은 3으로 고정합니다.
                  Navigator.pushNamed(
                    context,
                    '/adminUserProfile',
                    arguments: AdminUserProfileArguments(
                      targetPhoneNumber: memberPhone,
                      viewerPhoneNumber: leaderPhoneNumber,
                      viewerPermissionLevel: 3,
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
