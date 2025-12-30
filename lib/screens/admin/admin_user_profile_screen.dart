import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:panara_dialogs/panara_dialogs.dart';

import '../../utils/age_utils.dart';
import '../../utils/department_utils.dart'; // DepartmentCalculator import
import '../../utils/phone_utils.dart';
import '../../utils/user_utils.dart';

class AdminUserProfileArguments {
  final String targetPhoneNumber; // 프로필 대상의 전화번호
  final String viewerPhoneNumber; // 현재 보고 있는 관리자의 전화번호
  final int viewerPermissionLevel; // 현재 보고 있는 관리자의 권한

  AdminUserProfileArguments({
    required this.targetPhoneNumber,
    required this.viewerPhoneNumber,
    required this.viewerPermissionLevel,
  });
}

class AdminUserProfileScreen extends StatefulWidget {
  const AdminUserProfileScreen({super.key});

  @override
  State<AdminUserProfileScreen> createState() => _AdminUserProfileScreenState();
}

class _AdminUserProfileScreenState extends State<AdminUserProfileScreen> {
  late Future<QuerySnapshot<Map<String, dynamic>>> _userFuture;
  late final AdminUserProfileArguments _args;
  bool _initialized = false;
  // 대상 유저의 문서 ID를 저장할 변수
  String? _targetUserDocId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      final args = ModalRoute.of(context)!.settings.arguments;
      if (args is AdminUserProfileArguments) {
        _args = args;
        // 수정: 전화번호로 사용자 쿼리
        _userFuture = FirebaseFirestore.instance
            .collection('users')
            .where('phoneNumber', isEqualTo: _args.targetPhoneNumber)
            .limit(1)
            .get();
        _initialized = true;
      }
    }
  }

  // 대상 유저 삭제
  Future<void> _deleteUser() async {
    if (_targetUserDocId == null) return;
    // ... (기존 삭제 로직)
  }

  // 권한 변경
  Future<void> _changePermission(int newLevel) async {
    if (_targetUserDocId == null) return;
    await FirebaseFirestore.instance
        .collection('users')
        .doc(_targetUserDocId) // 수정: ID 사용
        .update({'permissionLevel': newLevel});
    setState(() {
      _userFuture = FirebaseFirestore.instance.collection('users')
          .where('phoneNumber', isEqualTo: _args.targetPhoneNumber).limit(1).get();
    });
  }
  
  // 태그 수정 (이 함수는 태그 수정 화면으로 이동하는 로직이 필요)
  void _editTags() {
    // TODO: 태그 수정 화면 구현 및 docId 전달
  }


  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return const Scaffold(body: Center(child: Text('잘못된 접근입니다.')));
    }

    return FutureBuilder<QuerySnapshot<Map<String, dynamic>>>(
      future: _userFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (snapshot.hasError || !snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Scaffold(body: Center(child: Text('사용자 정보를 불러올 수 없습니다.')));
        }

        final userDoc = snapshot.data!.docs.first;
        // 문서 ID 저장
        _targetUserDocId = userDoc.id;
        final data = userDoc.data();
        
        // ... (기존 UI 코드)
        final name = (data['name'] ?? '이름 없음').toString();
        final birthDate = data['birthDate'] as String?;
        // 수정: calculateAge -> calculateInternationalAge
        final age = AgeCalculator.calculateInternationalAge(birthDate);
        final classYear = (data['classYear'] ?? '').toString();
        // 수정: birthDate로 department를 실시간 계산
        final department = DepartmentCalculator.calculateDepartment(birthDate);
        final formattedPhone = formatPhoneNumber(_args.targetPhoneNumber);
        final permissionLevel = (data['permissionLevel'] ?? 4) as int;
        final tags = (data['tags'] as List<dynamic>? ?? []).map((tag) => tag.toString()).toList();

        final bool canEdit = _args.viewerPermissionLevel < permissionLevel;
        final bool isSelf = _args.viewerPhoneNumber == _args.targetPhoneNumber;

        return Scaffold(
          appBar: AppBar(
            title: Text(name),
            actions: [
              if (canEdit && !isSelf)
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'delete') {
                      _deleteUser();
                    }
                  },
                  itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                    const PopupMenuItem<String>(
                      value: 'delete',
                      child: Text('사용자 삭제'),
                    ),
                  ],
                ),
            ],
          ),
          body: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ... (기존 UI 위젯들)
                  _buildInfoCard(title: '기본 정보', details: {
                    '소속': department,
                    '기수': classYear,
                    '나이': age > 0 ? '$age세' : '정보 없음',
                    '생년월일': birthDate ?? '정보 없음',
                    '전화번호': formattedPhone,
                  }),
                  const SizedBox(height: 24),
                  _buildPermissionCard(
                    currentLevel: permissionLevel,
                    canEdit: canEdit,
                    onChanged: (newLevel) => _changePermission(newLevel),
                  ),
                  const SizedBox(height: 24),
                  _buildTagsCard(tags: tags, canEdit: canEdit, onEdit: _editTags),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ... (_buildInfoCard, _buildPermissionCard, _buildTagsCard 헬퍼 메서드는 변경 없음)
  Widget _buildInfoCard(
      {required String title, required Map<String, String> details}) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const Divider(height: 24),
            ...details.entries.map((e) => Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [Text(e.key, style: const TextStyle(color: Colors.grey)), Text(e.value)],
              ),
            ))
          ],
        ),
      ),
    );
  }

  Widget _buildPermissionCard({required int currentLevel, required bool canEdit, required ValueChanged<int> onChanged}) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('권한', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(getPermissionLabel(currentLevel)),
                if (canEdit)
                  PopupMenuButton<int>(
                    child: const Icon(Icons.edit),
                    onSelected: onChanged,
                    itemBuilder: (context) => [
                      const PopupMenuItem(value: 0, child: Text('사역자')),
                      const PopupMenuItem(value: 1, child: Text('팀장')),
                      const PopupMenuItem(value: 2, child: Text('리더')),
                      const PopupMenuItem(value: 3, child: Text('청년')),
                    ],
                  )
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildTagsCard({required List<String> tags, required bool canEdit, required VoidCallback onEdit}) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
             Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('태그', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                if (canEdit)
                  IconButton(icon: const Icon(Icons.edit), onPressed: onEdit)
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8.0,
              runSpacing: 4.0,
              children: tags.map((tag) => Chip(label: Text(tag))).toList(),
            )
          ],
        ),
      ),
    );
  }
}
