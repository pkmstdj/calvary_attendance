import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../utils/age_utils.dart';
import '../../utils/department_utils.dart'; // DepartmentCalculator import
import '../../utils/phone_utils.dart';

class ProfileTabScreen extends StatelessWidget {
  /// 표시할 사용자의 전화번호
  final String phoneNumber;

  const ProfileTabScreen({
    super.key,
    required this.phoneNumber,
  });

  @override
  Widget build(BuildContext context) {
    final userQuery = FirebaseFirestore.instance
        .collection('users')
        .where('phoneNumber', isEqualTo: phoneNumber)
        .limit(1);

    return Scaffold(
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: userQuery.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('정보를 불러오는 중 오류가 발생했습니다: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('사용자 정보를 찾을 수 없습니다.'));
          }

          final doc = snapshot.data!.docs.first;
          final data = doc.data();
          final userDocId = doc.id; // 문서 ID 가져오기

          final name = (data['name'] ?? '이름 없음').toString();
          final birthDate = data['birthDate'] as String?;
          final age = AgeCalculator.calculateInternationalAge(birthDate);
          final classYear = (data['classYear'] ?? '').toString();
          final department = DepartmentCalculator.calculateDepartment(birthDate);
          final formattedPhone = formatPhoneNumber(phoneNumber);
          final tags = (data['tags'] as List<dynamic>? ?? [])
              .map((tag) => tag.toString())
              .toList();

          return SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  _buildInfoCard(
                    context,
                    title: '기본 정보',
                    details: {
                      '소속': department,
                      '기수': classYear,
                      '나이': age > 0 ? '$age세' : '생년월일 정보 없음',
                      '생년월일': birthDate ?? '정보 없음',
                      '전화번호': formattedPhone,
                    },
                  ),
                  const SizedBox(height: 24),
                  if (tags.isNotEmpty) ...[
                    _buildTagsCard(context, tags: tags),
                    const SizedBox(height: 24),
                  ],
                  ElevatedButton.icon(
                    // 수정: onPressed에 화면 이동 로직 추가
                    onPressed: () {
                      Navigator.pushNamed(
                        context,
                        '/editProfile',
                        arguments: userDocId, // 문서 ID 전달
                      );
                    },
                    icon: const Icon(Icons.edit),
                    label: const Text('프로필 수정'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildInfoCard(BuildContext context,
      {required String title, required Map<String, String> details}) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const Divider(height: 24),
            ...details.entries.map((entry) => Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(entry.key,
                          style: const TextStyle(color: Colors.grey)),
                      Text(entry.value),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildTagsCard(BuildContext context, {required List<String> tags}) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('태그',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const Divider(height: 24),
            Wrap(
              spacing: 8.0,
              runSpacing: 4.0,
              children: tags.map((tag) => Chip(label: Text(tag))).toList(),
            ),
          ],
        ),
      ),
    );
  }
}
