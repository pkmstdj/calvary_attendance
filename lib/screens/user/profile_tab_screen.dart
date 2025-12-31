import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../utils/age_utils.dart';
import '../../utils/department_utils.dart';
import '../../utils/phone_utils.dart';

class ProfileTabScreen extends StatefulWidget {
  final String phoneNumber;

  const ProfileTabScreen({
    super.key,
    required this.phoneNumber,
  });

  @override
  State<ProfileTabScreen> createState() => _ProfileTabScreenState();
}

class _ProfileTabScreenState extends State<ProfileTabScreen> {
  // 전화번호로 리더의 표시 이름을 가져오는 함수
  Future<String> _getLeaderDisplayName(String phoneNumber) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('phoneNumber', isEqualTo: phoneNumber)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        final data = snapshot.docs.first.data();
        final name = data['name'] ?? '이름 없음';
        final classYear = data['classYear'] ?? '??';
        return '$classYear기 $name';
      }
    } catch (e) {
      return '정보 없음';
    }
    return '정보 없음';
  }

  @override
  Widget build(BuildContext context) {
    final userQuery = FirebaseFirestore.instance
        .collection('users')
        .where('phoneNumber', isEqualTo: widget.phoneNumber)
        .limit(1);

    return Scaffold(
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: userQuery.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
             return RefreshIndicator(
               onRefresh: () async {
                 setState(() {});
               },
               child: SingleChildScrollView(
                 physics: const AlwaysScrollableScrollPhysics(),
                 child: SizedBox(
                     height: MediaQuery.of(context).size.height * 0.8,
                     child: Center(child: Text('정보를 불러오는 중 오류가 발생했습니다: ${snapshot.error}'))
                 ),
               ),
             );
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return RefreshIndicator(
              onRefresh: () async {
                setState(() {});
              },
               child: SingleChildScrollView(
                 physics: const AlwaysScrollableScrollPhysics(),
                 child: SizedBox(
                     height: MediaQuery.of(context).size.height * 0.8,
                     child: const Center(child: Text('사용자 정보를 찾을 수 없습니다.'))
                 ),
               ),
            );
          }

          final doc = snapshot.data!.docs.first;
          final data = doc.data();
          final userDocId = doc.id;

          final name = (data['name'] ?? '이름 없음').toString();
          final birthDate = data['birthDate'] as String?;
          final age = AgeCalculator.calculateInternationalAge(birthDate);
          final classYear = (data['classYear'] ?? '').toString();
          final department = DepartmentCalculator.calculateDepartment(birthDate);
          final formattedPhone = formatPhoneNumber(widget.phoneNumber);
          final permissionLevel = (data['permissionLevel'] ?? 4) as int;
          final smallGroupLeaderPhone = data['smallGroupLeaderPhone'] as String?;
          final tags = (data['tags'] as List<dynamic>? ?? [])
              .map((tag) => tag.toString())
              .toList();

          return RefreshIndicator(
            onRefresh: () async {
              setState(() {});
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
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
                    // 소그룹 정보 카드 추가
                    if (permissionLevel >= 1 && permissionLevel <= 3 && smallGroupLeaderPhone != null && smallGroupLeaderPhone.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      _buildSmallGroupCard(context, leaderPhone: smallGroupLeaderPhone),
                    ],
                    const SizedBox(height: 24),
                    if (tags.isNotEmpty) ...[
                      _buildTagsCard(context, tags: tags),
                      const SizedBox(height: 24),
                    ],
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pushNamed(
                          context,
                          '/editProfile',
                          arguments: userDocId,
                        );
                      },
                      icon: const Icon(Icons.edit),
                      label: const Text('프로필 수정'),
                    ),
                  ],
                ),
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

  // 소그룹 정보 표시를 위한 새 카드 위젯
  Widget _buildSmallGroupCard(BuildContext context, {required String leaderPhone}) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('소그룹',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const Divider(height: 24),
            FutureBuilder<String>(
              future: _getLeaderDisplayName(leaderPhone),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)));
                }
                final leaderName = snapshot.data ?? '정보 없음';
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('리더', style: TextStyle(color: Colors.grey)),
                    Text(leaderName),
                  ],
                );
              },
            ),
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
