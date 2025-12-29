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
  String? _phoneNumber;
  late Future<DocumentSnapshot<Map<String, dynamic>>> _userFuture;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _birthController = TextEditingController();

  bool _isSaving = false;
  bool _initializedControllers = false;
  String? _birthDateError;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initializedControllers) {
      final args = ModalRoute.of(context)!.settings.arguments;
      if (args is String) {
        _phoneNumber = args;
        _userFuture =
            FirebaseFirestore.instance.collection('users').doc(_phoneNumber).get();
      }
    }
  }
  
  void _onBirthChanged(String value) {
    setState(() {
      _birthDateError = null;
    });

    final digits = value.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length >= 4) {
      final year = int.tryParse(digits.substring(0, 4));
      if (year != null) {
        final currentYear = DateTime.now().year;
        final age = currentYear - year + 1;
        if (age < 20 || age > 39) {
          setState(() {
            _birthDateError = '청년부 나이(20세~39세)가 아닙니다.';
          });
        }
      }
    }

    if (digits.length == 8 && !value.contains('-')) {
      final formatted = formatBirthDate(digits);
      _birthController.value = TextEditingValue(
        text: formatted,
        selection: TextSelection.collapsed(offset: formatted.length),
      );
    }
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
      ElegantNotification.error(
        title: const Text('오류'),
        description: const Text('이름과 생년월일을 모두 입력해 주세요.'),
      ).show(context);
      return;
    }
    
    if (_birthDateError != null) {
      ElegantNotification.error(
        title: const Text('오류'),
        description: Text(_birthDateError!),
      ).show(context);
      return;
    }

    if (_phoneNumber == null) {
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

      await FirebaseFirestore.instance
          .collection('users')
          .doc(_phoneNumber)
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
    if (_phoneNumber == null) {
      return const Scaffold(
        body: Center(child: Text('전화번호 정보가 없습니다.')),
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

            if (snapshot.hasError) {
              return Center(
                child: Text('사용자 정보를 불러오는 중 오류: ${snapshot.error}'),
              );
            }

            if (!snapshot.hasData || !snapshot.data!.exists) {
              return const Center(
                child: Text('사용자 정보를 찾을 수 없습니다.'),
              );
            }

            final data = snapshot.data!.data()!;
            if (!_initializedControllers) {
              _nameController.text = (data['name'] ?? '').toString();
              _birthController.text = (data['birthDate'] ?? '').toString();
              _initializedControllers = true;
            }

            return Padding(
              padding: const EdgeInsets.all(16),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      '전화번호: $_phoneNumber',
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
