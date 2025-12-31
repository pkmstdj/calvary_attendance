import 'package:calvary_attendance/widgets/news_card.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class HomeTabScreen extends StatefulWidget {
  final String phoneNumber;
  final int permissionLevel;
  final bool isPending;

  const HomeTabScreen({
    super.key,
    required this.phoneNumber,
    required this.permissionLevel,
    required this.isPending,
  });

  @override
  State<HomeTabScreen> createState() => _HomeTabScreenState();
}

class _HomeTabScreenState extends State<HomeTabScreen> {
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
        var dates = snapshot.docs
            .map((doc) => doc.data()['date'] as String)
            .toSet()
            .toList();

        final now = DateTime.now();
        final todayStr = '${now.year % 100}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';

        // 오늘 기준(오늘 포함) 과거 날짜만 필터링
        dates = dates.where((date) => date.compareTo(todayStr) <= 0).toList();

        // 최대 3개 항목만 표시
        if (dates.length > 3) {
          dates = dates.sublist(0, 3);
        }

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
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Column(
          children: [
            const SizedBox(height: 10),
            _buildHeader(),
            const SizedBox(height: 50),
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
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          'YCC 주보',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
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
        return DropdownMenuItem<String>(
          value: date,
          child: Text(_formatDate(date)),
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
