import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:panara_dialogs/panara_dialogs.dart';

import '../../utils/phone_utils.dart';

class AdminApprovalDetailArguments {
  final String phoneNumber;

  AdminApprovalDetailArguments({
    required this.phoneNumber,
  });
}

class AdminApprovalDetailScreen extends StatefulWidget {
  const AdminApprovalDetailScreen({super.key});

  @override
  State<AdminApprovalDetailScreen> createState() =>
      _AdminApprovalDetailScreenState();
}

class _AdminApprovalDetailScreenState extends State<AdminApprovalDetailScreen> {
  late AdminApprovalDetailArguments _args;
  bool _initialized = false;
  late Future<QuerySnapshot<Map<String, dynamic>>> _tagsFuture;
  List<String> _allTags = [];
  List<String> _selectedTags = [];
  bool _futuresInitialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      final args = ModalRoute.of(context)!.settings.arguments;
      if (args is AdminApprovalDetailArguments) {
        _args = args;
        _initialized = true;
      } else {
        // Handle error: arguments are not correct
      }
    }
    if (_initialized && !_futuresInitialized) {
      _tagsFuture = FirebaseFirestore.instance.collection('tags').get();
      _futuresInitialized = true;
    }
  }

  Future<void> _approve() async {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(_args.phoneNumber)
        .update({
      'permissionLevel': 3, // 4(미승인) -> 3(청년)
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
        await FirebaseFirestore.instance
            .collection('users')
            .doc(_args.phoneNumber)
            .delete();

        if (!mounted) return;
        Navigator.pop(context);
        Navigator.pop(context);
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
          List<String> tempSelectedTags = List.from(_selectedTags);
          return StatefulBuilder(
            builder: (context, setState) {
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
                          setState(() {
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
        });
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return const Scaffold(
        body: Center(child: Text('잘못된 접근입니다.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('승인 정보'),
      ),
      body: SafeArea(
        child: FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          future: FirebaseFirestore.instance
              .collection('users')
              .doc(_args.phoneNumber)
              .get(),
          builder: (context, userSnapshot) {
            if (userSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(),
              );
            }

            if (userSnapshot.hasError) {
              return Center(
                child: Text('사용자 정보를 불러오는 중 오류: ${userSnapshot.error}'),
              );
            }

            if (!userSnapshot.hasData || !userSnapshot.data!.exists) {
              return const Center(
                child: Text('사용자 정보를 찾을 수 없습니다.'),
              );
            }

            final data = userSnapshot.data!.data()!;
            final String name =
                (data['name'] ?? data['childName'] ?? '이름 없음').toString();
            final String formattedPhone = formatPhoneNumber(_args.phoneNumber);
            final String? birthDate = data['birthDate']?.toString();
            final List<dynamic> currentTags = data['tags'] as List<dynamic>? ?? [];
            if (_selectedTags.isEmpty && currentTags.isNotEmpty) {
               _selectedTags = currentTags.map((tag) => tag.toString()).toList();
            }

            return Padding(
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
                          Text(
                            '생년월일: $birthDate',
                            style: const TextStyle(fontSize: 16),
                          ),
                          const SizedBox(height: 4),
                        ],
                        Text(
                          '전화번호: $formattedPhone',
                          style: const TextStyle(fontSize: 16),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  FutureBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      future: _tagsFuture,
                      builder: (context, tagsSnapshot) {
                        if (tagsSnapshot.hasData) {
                          _allTags = tagsSnapshot.data!.docs
                              .map((doc) => doc.id as String)
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
                                label: const Text('태그 수정'))
                          ],
                        );
                      }),
                  const Spacer(),
                  const SizedBox(height: 12),
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
            );
          },
        ),
      ),
    );
  }
}
