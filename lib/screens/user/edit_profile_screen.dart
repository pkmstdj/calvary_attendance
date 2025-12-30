import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:elegant_notification/elegant_notification.dart';
import 'package:flutter/material.dart';

import '../../utils/date_utils.dart';
import '../../utils/user_utils.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  // 수정: phoneNumber 대신 userDocId를 사용
  String? _userDocId;
  late Future<DocumentSnapshot<Map<String, dynamic>>> _userFuture;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _birthController = TextEditingController();
  String _phoneNumberForDisplay = ''; // 화면 표기용 전화번호

  bool _isSaving = false;
  bool _initialized = false;
  String? _birthDateError;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      final args = ModalRoute.of(context)!.settings.arguments;
      // 수정: String으로 userDocId를 받음
      if (args is String) {
        _userDocId = args;
        _userFuture =
            FirebaseFirestore.instance.collection('users').doc(_userDocId).get();
        _initialized = true;
      }
    }
  }

  void _onBirthChanged(String value) {
    // ... (기존 로직 동일)
  }

  @override
  void dispose() {
    _nameController.dispose();
    _birthController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    final name = _nameController.text.trim();
    final birthRaw = _birthController.text.trim();

    if (name.isEmpty || birthRaw.isEmpty) {
      // ... (기존 오류 처리)
      return;
    }
    
    if (_birthDateError != null) {
      // ... (기존 오류 처리)
      return;
    }

    if (_userDocId == null) {
      ElegantNotification.error(
        title: const Text('오류'),
        description: const Text('사용자 정보가 없습니다. 다시 시도해 주세요.'),
      ).show(context);
      return;
    }

    if (_isSaving) return;
    setState(() {
      _isSaving = true;
    });

    try {
      final birth = formatBirthDate(birthRaw);

      // 수정: phoneNumber 대신 userDocId 사용
      await FirebaseFirestore.instance
          .collection('users')
          .doc(_userDocId)
          .update({
        'name': name,
        'birthDate': birth,
      });

      if (mounted) {
        ElegantNotification.success(
          title: const Text('성공'),
          description: const Text('프로필이 저장되었습니다.'),
        ).show(context);
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ElegantNotification.error(
          title: const Text('오류'),
          description: const Text('프로필 저장 중 오류가 발생했습니다.'),
        ).show(context);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return const Scaffold(
        body: Center(child: Text('사용자 정보가 없습니다.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('프로필 수정'),
      ),
      body: SafeArea(
        child: FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          future: _userFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError || !snapshot.hasData || !snapshot.data!.exists) {
              return const Center(child: Text('사용자 정보를 찾을 수 없습니다.'));
            }
            
            final data = snapshot.data!.data()!;
            // 컨트롤러 초기화 로직 수정
            if (_nameController.text.isEmpty && _birthController.text.isEmpty) {
              _nameController.text = (data['name'] ?? '').toString();
              _birthController.text = (data['birthDate'] ?? '').toString();
              _phoneNumberForDisplay = (data['phoneNumber'] ?? '').toString();
            }

            return Padding(
              padding: const EdgeInsets.all(16),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      '전화번호: $_phoneNumberForDisplay', // 화면 표기용 변수 사용
                      style: const TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: '이름',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _birthController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: '생년월일 (예: 1992-05-22)',
                        border: const OutlineInputBorder(),
                        errorText: _birthDateError,
                      ),
                      onChanged: _onBirthChanged,
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      height: 48,
                      child: _isSaving
                          ? const Center(child: CircularProgressIndicator())
                          : ElevatedButton(
                              onPressed: _birthDateError == null ? _saveProfile : null,
                              child: const Text(
                                '저장',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
