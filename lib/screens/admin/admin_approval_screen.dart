import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../utils/phone_utils.dart';
import 'admin_approval_detail_screen.dart';

class AdminApprovalScreen extends StatelessWidget {
  const AdminApprovalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // 수정: 'permissionLevel'이 4인 사용자(승인 대기)를 찾도록 쿼리 변경
    final pendingUsersQuery = FirebaseFirestore.instance
        .collection('users')
        .where('permissionLevel', isEqualTo: 4);

    return Scaffold(
      appBar: AppBar(
        title: const Text('승인 대기 목록'),
      ),
      body: SafeArea(
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: pendingUsersQuery.snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return const Center(child: Text('사용자 목록을 불러오는 중 오류가 발생했습니다.'));
            }

            final docs = snapshot.data?.docs ?? [];
            if (docs.isEmpty) {
              return const Center(child: Text('승인을 기다리는 사용자가 없습니다.'));
            }

            return ListView.separated(
              itemCount: docs.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final doc = docs[index];
                final data = doc.data();
                final name = (data['name'] ?? '이름 없음').toString();
                final phone = (data['phoneNumber'] ?? doc.id).toString();
                final formattedPhone = formatPhoneNumber(phone);

                return ListTile(
                  title: Text(name),
                  subtitle: Text(formattedPhone),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => AdminApprovalDetailScreen(
                          userData: data,
                        ),
                      ),
                    );
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }
}
