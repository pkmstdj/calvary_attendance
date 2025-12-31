import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AdminSharingTabScreen extends StatefulWidget {
  const AdminSharingTabScreen({super.key});

  @override
  State<AdminSharingTabScreen> createState() => _AdminSharingTabScreenState();
}

class _AdminSharingTabScreenState extends State<AdminSharingTabScreen> {
  String? _selectedDate; // yyMMdd 형식
  List<String> _availableDates = [];
  List<String> _questions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchAvailableDates();
  }

  // 1. 날짜 목록 가져오기 (education 컬렉션)
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

      // 관리자 모드: 미래 날짜 포함, 과거 날짜는 최신 3개만
      final futureDates = dates.where((date) => date.compareTo(todayStr) > 0).toList();
      final pastDates = dates.where((date) => date.compareTo(todayStr) <= 0).toList();
      
      final recentPastDates = pastDates.length > 3 ? pastDates.sublist(0, 3) : pastDates;
      
      dates = [...futureDates, ...recentPastDates];

      if (mounted) {
        setState(() {
          _availableDates = dates;
          // 선택된 날짜가 목록에 없으면 첫번째로 재설정
          if (_selectedDate == null || !_availableDates.contains(_selectedDate)) {
             if (_availableDates.isNotEmpty) {
               _selectedDate = _availableDates.first;
               _fetchDataForDate(_selectedDate!);
             } else {
               _selectedDate = null;
               _questions = [];
               _isLoading = false;
             }
          } else {
            // 선택된 날짜가 여전히 유효하면 데이터만 갱신
            _fetchDataForDate(_selectedDate!);
          }
        });
      }
    } catch (e) {
      debugPrint('Error fetching dates: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // 2. 선택된 날짜의 질문 가져오기 (답변 로드 X)
  Future<void> _fetchDataForDate(String date) async {
    setState(() => _isLoading = true);
    _questions = [];

    try {
      final eduDoc = await FirebaseFirestore.instance.collection('education').doc(date).get();
      if (eduDoc.exists && eduDoc.data() != null) {
        final data = eduDoc.data()!;
        if (data.containsKey('questions') && data['questions'] is List) {
          _questions = List<String>.from(data['questions']);
        }
      }
    } catch (e) {
      debugPrint('Error fetching data: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('나눔 질문 확인'),
      ),
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
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (_availableDates.isNotEmpty && _selectedDate != null)
          DropdownButton<String>(
            value: _selectedDate,
            underline: Container(
              height: 1,
              color: Colors.grey.shade400,
            ),
            items: _availableDates.map((String date) {
               String label = _formatDate(date);
        
                // 미래 날짜인지 확인하여 (예정) 추가
                final now = DateTime.now();
                final todayStr = '${now.year % 100}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
                if (date.compareTo(todayStr) > 0) {
                  label += ' (예정)';
                }

              return DropdownMenuItem<String>(
                value: date,
                child: Text(label),
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
        onRefresh: _fetchAvailableDates,
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
      onRefresh: _fetchAvailableDates,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: List.generate(_questions.length, (index) {
            return _buildQuestionItem(index, _questions[index]);
          }),
        ),
      ),
    );
  }

  Widget _buildQuestionItem(int index, String question) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Q${index + 1}',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).primaryColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              question,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
