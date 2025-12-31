import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class EducationTeamTab extends StatefulWidget {
  const EducationTeamTab({super.key});

  @override
  State<EducationTeamTab> createState() => _EducationTeamTabState();
}

class _EducationTeamTabState extends State<EducationTeamTab> {
  DateTime _selectedDate = DateTime.now();
  final List<TextEditingController> _questionControllers = [TextEditingController()];
  bool _isUploading = false;

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2101),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  void _addQuestionField() {
    setState(() {
      _questionControllers.add(TextEditingController());
    });
  }

  void _removeQuestionField(int index) {
    if (_questionControllers.length > 1) {
      setState(() {
        _questionControllers[index].dispose();
        _questionControllers.removeAt(index);
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('최소 하나 이상의 문항이 필요합니다.')),
      );
    }
  }

  Future<String?> _getUserIdFromPhoneNumber() async {
    final prefs = await SharedPreferences.getInstance();
    final phoneNumber = prefs.getString('savedPhoneNumber');
    if (phoneNumber == null) return null;

    final querySnapshot = await FirebaseFirestore.instance
        .collection('users')
        .where('phoneNumber', isEqualTo: phoneNumber)
        .limit(1)
        .get();

    if (querySnapshot.docs.isNotEmpty) {
      return querySnapshot.docs.first.id;
    }
    return null;
  }

  Future<void> _uploadQuestions() async {
    final questions = _questionControllers
        .map((controller) => controller.text.trim())
        .where((question) => question.isNotEmpty)
        .toList();

    if (questions.length != _questionControllers.length) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('모든 문항을 입력해주세요.')),
      );
      return;
    }

    final uploaderId = await _getUserIdFromPhoneNumber();
    if (uploaderId == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('사용자 정보를 찾을 수 없습니다. 다시 로그인 해주세요.')),
      );
      return;
    }

    setState(() {
      _isUploading = true;
    });

    try {
      final String formattedDate = DateFormat('yyMMdd').format(_selectedDate);
      final educationCollection = FirebaseFirestore.instance.collection('education');

      await educationCollection.doc(formattedDate).set({
        'questions': questions,
        'timestamp': FieldValue.serverTimestamp(),
        'approved': false,
        'date': formattedDate,
        'uploaderId': uploaderId,
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('문항이 업로드 요청되었습니다.')),
      );
      setState(() {
        for (var controller in _questionControllers) {
          controller.clear();
        }
        while (_questionControllers.length > 1) {
          _questionControllers.last.dispose();
          _questionControllers.removeLast();
        }
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('업로드 실패: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    for (var controller in _questionControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          // 하단 여백 추가
          padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 80.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('날짜 선택', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(DateFormat('yyyy년 MM월 dd일').format(_selectedDate)),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () => _selectDate(context),
                    child: const Text('날짜 변경'),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Text('문항 입력', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _questionControllers.length,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _questionControllers[index],
                            decoration: InputDecoration(
                              labelText: '문항 ${index + 1}',
                              border: const OutlineInputBorder(),
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.remove_circle_outline),
                          onPressed: () => _removeQuestionField(index),
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 8),
              ElevatedButton.icon(
                onPressed: _addQuestionField,
                icon: const Icon(Icons.add),
                label: const Text('문항 추가'),
              ),
              const SizedBox(height: 24),
              if (_isUploading)
                const Center(child: CircularProgressIndicator())
              else
                Center(
                  child: ElevatedButton(
                    onPressed: _uploadQuestions,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 40, vertical: 16),
                    ),
                    child: const Text('업로드'),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
