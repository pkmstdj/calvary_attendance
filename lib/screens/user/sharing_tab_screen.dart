import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SharingTabScreen extends StatefulWidget {
  final String? currentUserPhoneNumber;
  final int? currentUserPermissionLevel;

  const SharingTabScreen({
    super.key,
    this.currentUserPhoneNumber,
    this.currentUserPermissionLevel,
  });

  @override
  State<SharingTabScreen> createState() => _SharingTabScreenState();
}

class _SharingTabScreenState extends State<SharingTabScreen> {
  String? _selectedDate; // yyMMdd 형식
  List<String> _availableDates = [];
  List<String> _questions = [];
  bool _isLoading = true;
  final Map<int, TextEditingController> _controllers = {};
  final _debouncer = Debouncer(milliseconds: 1000); // 1초 뒤 자동 저장
  
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _initializeUserAndDates();
  }

  @override
  void dispose() {
    _controllers.forEach((_, controller) => controller.dispose());
    super.dispose();
  }

  Future<void> _initializeUserAndDates() async {
    await _fetchUserId();
    await _fetchAvailableDates();
  }

  Future<void> _fetchUserId() async {
    // Auth UID 사용 로직 제거. 무조건 phoneNumber로 매칭되는 문서를 찾음.
    if (widget.currentUserPhoneNumber != null) {
      try {
        final snapshot = await FirebaseFirestore.instance
            .collection('users')
            .where('phoneNumber', isEqualTo: widget.currentUserPhoneNumber)
            .limit(1)
            .get();
        
        if (snapshot.docs.isNotEmpty) {
          // 전화번호가 일치하는 문서의 ID를 사용 (이것이 내 계정 문서)
          _currentUserId = snapshot.docs.first.id;
        } else {
          debugPrint('User not found with phone number: ${widget.currentUserPhoneNumber}');
        }
      } catch (e) {
        debugPrint('Error fetching user ID: $e');
      }
    }
  }

  // 1. 날짜 목록 가져오기 (education 컬렉션의 문서 ID가 날짜라고 가정)
  Future<void> _fetchAvailableDates() async {
    try {
      // approved가 true인 문서만 가져옴
      final snapshot = await FirebaseFirestore.instance
          .collection('education')
          .where('approved', isEqualTo: true)
          .get();
      
      final now = DateTime.now();
      final todayStr = '${now.year % 100}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';

      List<String> dates = snapshot.docs.map((doc) => doc.id).where((id) {
        // yyMMdd 형식이 맞는지 간단한 체크
        return RegExp(r'^\d{6}$').hasMatch(id);
      }).toList();

      // 내림차순 정렬 (최신 날짜 우선)
      dates.sort((a, b) => b.compareTo(a));

      // 오늘 포함 과거 날짜만 필터링
      dates = dates.where((date) => date.compareTo(todayStr) <= 0).toList();

      // 최대 3개만 선택
      if (dates.length > 3) {
        dates = dates.sublist(0, 3);
      }

      if (mounted) {
        setState(() {
          _availableDates = dates;
          if (_availableDates.isNotEmpty) {
            _selectedDate = _availableDates.first;
            _fetchDataForDate(_selectedDate!);
          } else {
            _isLoading = false;
          }
        });
      }
    } catch (e) {
      debugPrint('Error fetching dates: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // 2. 선택된 날짜의 질문과 내 답변 가져오기
  Future<void> _fetchDataForDate(String date) async {
    setState(() => _isLoading = true);
    _questions = [];
    _controllers.clear();

    try {
      // 2-1. 질문 가져오기
      final eduDoc = await FirebaseFirestore.instance.collection('education').doc(date).get();
      if (eduDoc.exists && eduDoc.data() != null) {
        final data = eduDoc.data()!;
        if (data.containsKey('questions') && data['questions'] is List) {
          _questions = List<String>.from(data['questions']);
        }
      }

      // 2-2. 내 답변 가져오기 (DB) - _currentUserId 사용
      Map<String, dynamic> remoteAnswers = {};
      if (_currentUserId != null) {
        try {
          final answerDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(_currentUserId)
              .collection('sharingAnswers')
              .doc(date)
              .get();
          
          if (answerDoc.exists && answerDoc.data() != null) {
            remoteAnswers = answerDoc.data()!;
          }
        } catch (e) {
          debugPrint('Error fetching remote answers: $e');
        }
      }

      // 2-3. 로컬 저장소 준비
      final prefs = await SharedPreferences.getInstance();

      // 2-4. 컨트롤러 초기화 (로컬 우선)
      for (int i = 0; i < _questions.length; i++) {
        String finalAnswer = '';
        
        // 로컬 값 확인
        final localKey = 'sharing_${date}_$i';
        final localValue = prefs.getString(localKey);

        // DB 값 확인
        final remoteValue = remoteAnswers[i.toString()] as String? ?? '';

        // 로컬 값이 존재하고 공백이 아니면 우선 사용
        if (localValue != null && localValue.trim().isNotEmpty) {
          finalAnswer = localValue;
        } else {
          finalAnswer = remoteValue;
        }

        _controllers[i] = TextEditingController(text: finalAnswer);
      }

    } catch (e) {
      debugPrint('Error fetching data: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // 3. 답변 자동 저장
  void _onAnswerChanged(int index, String text) {
    _debouncer.run(() {
      _saveAnswer(index, text);
    });
  }

  Future<void> _saveAnswer(int index, String text) async {
    // _currentUserId가 없는 경우 재시도 (혹시 초기화 늦어질 경우 대비)
    if (_currentUserId == null) {
      await _fetchUserId();
    }
    
    if (_currentUserId == null || _selectedDate == null) return;

    try {
      // 1. 로컬에 먼저 저장 (오프라인 대응 및 우선순위 확보)
      final prefs = await SharedPreferences.getInstance();
      final localKey = 'sharing_${_selectedDate}_$index';
      await prefs.setString(localKey, text);
      debugPrint('Local saved: $localKey');

      // 2. DB 저장 시도 - _currentUserId 사용
      await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUserId)
          .collection('sharingAnswers')
          .doc(_selectedDate)
          .set({
            index.toString(): text,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
      
      debugPrint('DB Answer $index saved for $_selectedDate at users/$_currentUserId/sharingAnswers/$_selectedDate');
    } catch (e) {
      debugPrint('Error saving answer to DB (Local saved): $e');
      // DB 저장이 실패해도 로컬에는 저장되었으므로 사용자는 데이터를 잃지 않음
    }
  }

  String _formatDate(String dateYyMmDd) {
    if (dateYyMmDd.length != 6) return dateYyMmDd;
    try {
      final String year = '20${dateYyMmDd.substring(0, 2)}';
      final String month = dateYyMmDd.substring(2, 4);
      final String day = dateYyMmDd.substring(4, 6);
      return '$year년 $month월 $day일';
    } catch (e) {
      return dateYyMmDd;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.currentUserPhoneNumber == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
              child: _buildHeader(),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _buildContent(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          '나눔 질문',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        if (_availableDates.isNotEmpty && _selectedDate != null)
          DropdownButton<String>(
            value: _selectedDate,
            underline: Container(
              height: 1,
              color: Colors.grey.shade400,
            ),
            items: _availableDates.map((String date) {
              return DropdownMenuItem<String>(
                value: date,
                child: Text(_formatDate(date)),
              );
            }).toList(),
            onChanged: (String? newValue) {
              if (newValue != null && newValue != _selectedDate) {
                setState(() {
                  _selectedDate = newValue;
                });
                _fetchDataForDate(newValue);
              }
            },
          ),
      ],
    );
  }

  Widget _buildContent() {
    if (_questions.isEmpty) {
      return RefreshIndicator(
        onRefresh: _initializeUserAndDates,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Container(
            height: MediaQuery.of(context).size.height * 0.7,
            alignment: Alignment.center,
            child: const Text('등록된 나눔 질문이 없습니다.'),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        await _initializeUserAndDates();
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: List.generate(_questions.length, (index) {
            return _buildQuestionSet(index, _questions[index]);
          }),
        ),
      ),
    );
  }

  Widget _buildQuestionSet(int index, String question) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 질문 텍스트
          Text(
            'Q${index + 1}. $question',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          // 입력 필드
          TextField(
            controller: _controllers[index],
            onChanged: (text) => _onAnswerChanged(index, text),
            maxLines: 4, // 보이는 줄 수
            minLines: 4,
            keyboardType: TextInputType.multiline,
            decoration: InputDecoration(
              hintText: '자유롭게 내용을 작성해주세요.',
              hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
              filled: true,
              fillColor: Colors.grey.shade50,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Theme.of(context).primaryColor),
              ),
              contentPadding: const EdgeInsets.all(16),
            ),
          ),
        ],
      ),
    );
  }
}

// 디바운서 클래스 (입력 멈춤 감지)
class Debouncer {
  final int milliseconds;
  Timer? _timer;

  Debouncer({required this.milliseconds});

  void run(VoidCallback action) {
    _timer?.cancel();
    _timer = Timer(Duration(milliseconds: milliseconds), action);
  }
}
