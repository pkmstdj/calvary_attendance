import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:panara_dialogs/panara_dialogs.dart';

import '../../utils/department_utils.dart'; // DepartmentCalculator import
import '../../utils/phone_utils.dart';

class AdminApprovalDetailScreen extends StatefulWidget {
  // 사용자 데이터를 Map 형태로 직접 받음
  final Map<String, dynamic> userData;

  const AdminApprovalDetailScreen({
    super.key,
    required this.userData,
  });

  @override
  State<AdminApprovalDetailScreen> createState() =>
      _AdminApprovalDetailScreenState();
}

class _AdminApprovalDetailScreenState extends State<AdminApprovalDetailScreen> {
  late Future<QuerySnapshot<Map<String, dynamic>>> _tagsFuture;
  List<String> _allTags = [];
  List<String> _selectedTags = [];

  // initState에서 phoneNumber를 가져와 초기화
  late final String _phoneNumber;

  @override
  void initState() {
    super.initState();
    _phoneNumber = widget.userData['phoneNumber']?.toString() ?? '';
    _tagsFuture = FirebaseFirestore.instance.collection('tags').get();
    
    // 초기 선택된 태그 설정
    final currentTags = widget.userData['tags'] as List<dynamic>? ?? [];
    _selectedTags = currentTags.map((tag) => tag.toString()).toList();
  }

  // 전화번호로 문서 ID를 찾는 헬퍼 함수
  Future<String?> _getUserDocIdByPhone(String phone) async {
    final querySnapshot = await FirebaseFirestore.instance
        .collection('users')
        .where('phoneNumber', isEqualTo: phone)
        .limit(1)
        .get();
    if (querySnapshot.docs.isNotEmpty) {
      return querySnapshot.docs.first.id;
    }
    return null;
  }

  Future<void> _approve() async {
    final docId = await _getUserDocIdByPhone(_phoneNumber);
    if (docId == null) return;

    await FirebaseFirestore.instance
        .collection('users')
        .doc(docId) // 수정: 전화번호 대신 문서 ID 사용
        .update({
      'permissionLevel': 3,
      'tags': _selectedTags,
    });

    if (!mounted) return;
    Navigator.pop(context);
  }

  Future<void> _reject() async {
    PanaraConfirmDialog.show(
      context,
      title: '승인 거절',
      message: '이 사용자의 가입 요청을 거절하고 목록에서 삭제하시겠습니까?',
      confirmButtonText: '예',
      cancelButtonText: '아니오',
      onTapConfirm: () async {
        final docId = await _getUserDocIdByPhone(_phoneNumber);
        if (docId != null) {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(docId) // 수정: 전화번호 대신 문서 ID 사용
              .delete();
        }

        if (!mounted) return;
        Navigator.pop(context); // Panara Dialog 닫기
        Navigator.pop(context); // DetailScreen 닫기
      },
      onTapCancel: () {
        Navigator.pop(context);
      },
      panaraDialogType: PanaraDialogType.error,
      barrierDismissible: false,
    );
  }

  void _showTagSelectionDialog() {
    showDialog(
      context: context,
      builder: (context) {
        // 임시로 사용할 태그 리스트 (취소 시 원본 유지)
        List<String> tempSelectedTags = List.from(_selectedTags);
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('태그 선택'),
              content: SizedBox(
                width: double.maxFinite,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _allTags.length,
                  itemBuilder: (context, index) {
                    final tag = _allTags[index];
                    return CheckboxListTile(
                      title: Text(tag),
                      value: tempSelectedTags.contains(tag),
                      onChanged: (bool? value) {
                        setStateDialog(() {
                          if (value == true) {
                            tempSelectedTags.add(tag);
                          } else {
                            tempSelectedTags.remove(tag);
                          }
                        });
                      },
                    );
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('취소'),
                ),
                TextButton(
                  onPressed: () {
                    // 메인 화면의 상태를 업데이트
                    setState(() {
                      _selectedTags = tempSelectedTags;
                    });
                    Navigator.pop(context);
                  },
                  child: const Text('확인'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final String name = (widget.userData['name'] ?? '이름 없음').toString();
    final String formattedPhone = formatPhoneNumber(_phoneNumber);
    final String? birthDate = widget.userData['birthDate']?.toString();
    // 수정: birthDate로 department를 실시간 계산
    final String department = DepartmentCalculator.calculateDepartment(birthDate);

    return Scaffold(
      appBar: AppBar(
        title: const Text('승인 정보'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (birthDate != null && birthDate.isNotEmpty) ...[
                      Text('생년월일: $birthDate'),
                      const SizedBox(height: 4),
                    ],
                     if (department.isNotEmpty) ...[
                      Text('소속: $department'),
                      const SizedBox(height: 4),
                    ],
                    Text('전화번호: $formattedPhone'),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              FutureBuilder<QuerySnapshot<Map<String, dynamic>>>(
                future: _tagsFuture,
                builder: (context, tagsSnapshot) {
                  if (tagsSnapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (tagsSnapshot.hasData) {
                    // Firestore에서 태그 이름 가져오기 (수정: doc.id -> doc['name'])
                    _allTags = tagsSnapshot.data!.docs
                        .map((doc) => doc.data()['name'] as String)
                        .toList();
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('태그', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8.0,
                        runSpacing: 4.0,
                        children: _selectedTags.map((tag) => Chip(label: Text(tag))).toList(),
                      ),
                      TextButton.icon(
                        onPressed: _showTagSelectionDialog,
                        icon: const Icon(Icons.edit),
                        label: const Text('태그 수정'),
                      ),
                    ],
                  );
                },
              ),
              const Spacer(),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _reject,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey,
                        ),
                        child: const Text('거절'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _approve,
                        child: const Text('승인'),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
