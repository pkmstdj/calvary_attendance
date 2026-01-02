import 'package:calvary_attendance/widgets/news_card.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AdminMainTab extends StatefulWidget {
  final String phoneNumber;
  final int permissionLevel;

  const AdminMainTab({
    super.key,
    required this.phoneNumber,
    required this.permissionLevel,
  });

  @override
  State<AdminMainTab> createState() => _AdminMainTabState();
}

class _AdminMainTabState extends State<AdminMainTab> {
  String? _selectedDate;
  List<String> _availableDates = [];

  @override
  void initState() {
    super.initState();
    _fetchAvailableDates();
  }

  Future<void> _fetchAvailableDates() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('news')
          .where('approved', isEqualTo: true)
          .orderBy('date', descending: true)
          .get();

      if (snapshot.docs.isNotEmpty) {
        final allDates = snapshot.docs
            .map((doc) => doc.data()['date'] as String)
            .toSet()
            .toList();

        final now = DateTime.now();
        final todayStr = '${now.year % 100}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';

        // 미래 날짜 필터링
        final futureDates = allDates.where((date) => date.compareTo(todayStr) > 0).toList();
        
        // 과거 날짜(오늘 포함) 필터링
        final pastDates = allDates.where((date) => date.compareTo(todayStr) <= 0).toList();
        
        // 과거 날짜 중 최신 3개만 선택
        final recentPastDates = pastDates.length > 3 ? pastDates.sublist(0, 3) : pastDates;

        // 최종 리스트: 미래 날짜들 + 최신 과거 날짜들
        final dates = [...futureDates, ...recentPastDates];

        if (mounted) {
          setState(() {
            _availableDates = dates;
            if (_availableDates.isNotEmpty) {
               // 현재 선택된 날짜가 목록에 없으면(예: 날짜가 바뀌어서 사라짐) 첫번째로 변경
               if (_selectedDate == null || !_availableDates.contains(_selectedDate)) {
                 _selectedDate = _availableDates.first;
               }
            }
          });
        }
      }
    } catch (e) {
      // Handle error
    }
  }

  String _formatDate(String dateYyMmDd) {
    if (dateYyMmDd.length != 6) {
      return dateYyMmDd;
    }
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
        title: const Text('주보 관리'),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Column(
          children: [
            _buildHeader(),
            const SizedBox(height: 16),
            Expanded(
              child: _selectedDate == null
                  ? const Center(child: Text('주보를 불러오는 중입니다...'))
                  : _buildImageFeed(),
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
        if (_availableDates.isNotEmpty) _buildDateDropdown(),
      ],
    );
  }

  Widget _buildDateDropdown() {
    return DropdownButton<String>(
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
        setState(() {
          _selectedDate = newValue;
        });
      },
    );
  }

  Widget _buildImageFeed() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('news')
          .where('approved', isEqualTo: true)
          .where('date', isEqualTo: _selectedDate)
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError || !snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return RefreshIndicator(
            onRefresh: _fetchAvailableDates,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                SizedBox(height: MediaQuery.of(context).size.height * 0.3),
                const Center(child: Text('해당 날짜에 주보가 없습니다.')),
              ],
            ),
          );
        }

        final newsDocs = snapshot.data!.docs;

        return RefreshIndicator(
          onRefresh: _fetchAvailableDates,
          child: ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: newsDocs.length,
            separatorBuilder: (context, index) => const SizedBox(height: 24),
            itemBuilder: (context, index) {
              final newsData = newsDocs[index].data();
              final imageUrls = List<String>.from(newsData['imageUrls'] ?? []);
              
              return NewsCard(
                imageUrls: imageUrls,
                date: _selectedDate,
              );
            },
          ),
        );
      },
    );
  }
}
