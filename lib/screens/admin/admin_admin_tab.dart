import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../utils/phone_utils.dart';
import '../../utils/user_utils.dart';
import 'admin_user_profile_screen.dart';

class AdminAdminTab extends StatefulWidget {
  /// 현재 로그인한 관리자 전화번호
  final String phoneNumber;

  /// 현재 로그인한 관리자 권한 레벨
  final int permissionLevel;

  const AdminAdminTab({
    super.key,
    required this.phoneNumber,
    required this.permissionLevel,
  });

  @override
  State<AdminAdminTab> createState() => _AdminAdminTabState();
}

class _AdminAdminTabState extends State<AdminAdminTab> {
  @override
  Widget build(BuildContext context) {
    // 권한 2(리더)까지를 "관리자 관리" 목록에 포함
    final adminsQuery = FirebaseFirestore.instance
        .collection('users')
        .where('permissionLevel', isLessThanOrEqualTo: 2);

    // 승인 대기자 (permissionLevel == 4) 카운트 (수정: isEqualTo -> isGreaterThanOrEqualTo)
    final pendingQuery = FirebaseFirestore.instance
        .collection('users')
        .where('permissionLevel', isEqualTo: 4);

    return Scaffold(
      appBar: AppBar(
        title: const Text('관리자 관리'),
        actions: [
          if (widget.permissionLevel == 0) // 사역자만 태그 관리 버튼 표시
            IconButton(
              icon: const Icon(Icons.tag),
              // 수정: '/tagManagement' -> '/adminTag'
              onPressed: () => Navigator.pushNamed(context, '/adminTag'),
            ),
          // 승인 대기 화면 이동 아이콘 + 뱃지
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: pendingQuery.snapshots(),
            builder: (context, snapshot) {
              final count = snapshot.data?.docs.length ?? 0;
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  IconButton(
                    onPressed: () {
                      // 수정: '/adminApprovalList' -> '/adminApproval'
                      Navigator.pushNamed(context, '/adminApproval');
                    },
                    icon: const Icon(Icons.notifications),
                    tooltip: '승인 대기 목록',
                  ),
                  if (count > 0)
                    Positioned(
                      right: 4,
                      top: 4,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.redAccent,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '$count',
                          style: const TextStyle(
                            fontSize: 10,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: adminsQuery.snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(),
              );
            }
            if (snapshot.hasError) {
              return const Center(
                child: Text('관리자 목록을 불러오는 중 오류가 발생했습니다.'),
              );
            }

            final docs = snapshot.data?.docs ?? [];
            if (docs.isEmpty) {
              return const Center(
                child: Text('등록된 관리자가 없습니다.'),
              );
            }

            // 권한 오름차순(숫자 작은 사람 = 더 높은 등급)으로 정렬
            docs.sort((a, b) {
              final pa = (a.data()['permissionLevel'] ?? 3) as int;
              final pb = (b.data()['permissionLevel'] ?? 3) as int;
              if (pa != pb) return pa.compareTo(pb);
              final na = (a.data()['name'] ?? '').toString();
              final nb = (b.data()['name'] ?? '').toString();
              return na.compareTo(nb);
            });

            return ListView.separated(
              itemCount: docs.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final data = docs[index].data();
                final name = (data['name'] ?? '이름 없음').toString();
                final phone =
                (data['phoneNumber'] ?? docs[index].id).toString();
                final permission =
                (data['permissionLevel'] ?? 3) as int;

                final formattedPhone = formatPhoneNumber(phone);
                final permissionText = getPermissionLabel(permission);

                return ListTile(
                  title: Text(name),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        formattedPhone,
                        style: const TextStyle(fontSize: 12),
                      ),
                      Text(
                        permissionText,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.brown,
                        ),
                      ),
                    ],
                  ),
                  onTap: () {
                    // 이 관리자의 프로필 화면으로 이동
                    Navigator.pushNamed(
                      context,
                      '/adminUserProfile',
                      arguments: AdminUserProfileArguments(
                        targetPhoneNumber: phone,
                        viewerPhoneNumber: widget.phoneNumber,
                        viewerPermissionLevel: widget.permissionLevel,
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
