import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../utils/phone_utils.dart';
import 'admin_approval_detail_screen.dart';

class AdminApprovalScreen extends StatelessWidget {
  const AdminApprovalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final query = FirebaseFirestore.instance
        .collection('users')
        .where('permissionLevel', isEqualTo: 5)
        .orderBy('name');

    return Scaffold(
      appBar: AppBar(
        title: const Text('승인 대기'),
      ),
      body: SafeArea(
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: query.snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(),
              );
            }

            if (snapshot.hasError) {
              return const Center(
                child: Text('승인 대기자를 불러오는 중 오류가 발생했습니다.'),
              );
            }

            final docs = snapshot.data?.docs ?? [];
            if (docs.isEmpty) {
              return const Center(
                child: Text('승인 대기 중인 사용자가 없습니다.'),
              );
            }

            return ListView.separated(
              itemCount: docs.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final doc = docs[index];
                final data = doc.data();
                final String name =
                    (data['name'] ?? data['childName'] ?? '이름 없음')
                        .toString();
                final String phone =
                    (data['phoneNumber'] ?? '').toString();
                final String formattedPhone = formatPhoneNumber(phone);

                return ListTile(
                  title: Text(name),
                  subtitle: Text(
                    formattedPhone,
                    style: const TextStyle(fontSize: 12),
                  ),
                  onTap: () {
                    Navigator.pushNamed(
                      context,
                      '/adminApprovalDetail',
                      arguments: AdminApprovalDetailArguments(
                        phoneNumber: phone,
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
