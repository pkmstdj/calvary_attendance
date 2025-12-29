import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart'; // Firebase Auth 패키지 import
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:photo_view/photo_view.dart';

class BulletinCard extends StatefulWidget {
  // phoneNumber 속성 제거
  const BulletinCard({super.key});

  @override
  State<BulletinCard> createState() => _BulletinCardState();
}

class _BulletinCardState extends State<BulletinCard> {
  List<String> _availableDates = []; // 'yymmdd' 형식의 날짜 목록
  String? _selectedDate; // 현재 선택된 'yymmdd' 날짜
  List<String> _bulletinPageUrls = []; // 선택된 주보의 페이지 이미지 URL 목록
  bool _isLoadingDates = true;
  bool _isLoadingPages = false;
  String? _error;

  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController.addListener(() {
      if (_pageController.page?.round() != _currentPage) {
        setState(() {
          _currentPage = _pageController.page!.round();
        });
      }
    });
    // FirebaseAuth를 통해 실제 로그인 상태를 확인
    if (FirebaseAuth.instance.currentUser != null) {
      _fetchRecentBulletinDates();
    } else {
      setState(() {
        _isLoadingDates = false;
      });
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  String? _parseDateFromFilename(String filename) {
    final parts = filename.split('_');
    if (parts.length >= 2 && parts[0] == 'news' && parts[1].length == 6) {
      return parts[1];
    }
    return null;
  }

  String _formatDateForDisplay(String yymmdd) {
    try {
      final date = DateFormat('yyMMdd').parse(yymmdd);
      return DateFormat('yy년 MM월 dd일').format(date);
    } catch (e) {
      return yymmdd;
    }
  }

  Future<void> _fetchRecentBulletinDates() async {
    if (!mounted) return;
    setState(() {
      _isLoadingDates = true;
      _error = null;
    });
    try {
      final listResult = await FirebaseStorage.instance.ref('news').listAll();
      final Set<String> dates = {};
      for (final ref in listResult.items) {
        final date = _parseDateFromFilename(ref.name);
        if (date != null) {
          dates.add(date);
        }
      }

      final sortedDates = dates.toList()..sort((a, b) => b.compareTo(a));
      final recentDates = sortedDates.take(3).toList();

      if (!mounted) return;

      setState(() {
        _availableDates = recentDates;
        _isLoadingDates = false;
        if (_availableDates.isNotEmpty) {
          _selectedDate = _availableDates.first;
          _fetchBulletinPages(_selectedDate!);
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '주보 날짜를 불러오는 중 오류가 발생했습니다.';
        _isLoadingDates = false;
      });
    }
  }

  Future<void> _fetchBulletinPages(String date) async {
    if (!mounted) return;
    setState(() {
      _isLoadingPages = true;
      _error = null;
    });
    try {
      final listResult = await FirebaseStorage.instance.ref('news').listAll();
      final pageRefs = listResult.items
          .where((ref) => ref.name.startsWith('news_${date}_'))
          .toList();

      pageRefs.sort((a, b) {
        try {
          final pageNumA = int.parse(a.name.split('_').last.split('.').first);
          final pageNumB = int.parse(b.name.split('_').last.split('.').first);
          return pageNumA.compareTo(pageNumB);
        } catch (e) {
          return 0;
        }
      });

      final urls = await Future.wait(pageRefs.map((ref) => ref.getDownloadURL()));

      if (!mounted) return;

      setState(() {
        _bulletinPageUrls = urls;
        _isLoadingPages = false;
        _currentPage = 0; 
        _pageController.jumpToPage(0);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '주보를 불러오는 중 오류가 발생했습니다.';
        _isLoadingPages = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // FirebaseAuth를 통해 실제 로그인 상태를 확인하여 위젯 표시 여부 결정
    if (FirebaseAuth.instance.currentUser == null) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Text(
                  '주보',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                _buildDropdown(),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _buildPageView(),
          if (_bulletinPageUrls.length > 1)
            _buildPageIndicator(),
        ],
      ),
    );
  }

  Widget _buildDropdown() {
    if (_isLoadingDates) {
      return const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 3));
    }
    if (_availableDates.isEmpty) {
      return const Text('주보 없음');
    }
    return DropdownButton<String>(
      value: _selectedDate,
      underline: const SizedBox.shrink(),
      hint: const Text('날짜 선택'),
      items: _availableDates.map((date) {
        return DropdownMenuItem(
          value: date,
          child: Text(_formatDateForDisplay(date)),
        );
      }).toList(),
      onChanged: (newDate) {
        if (newDate != null && newDate != _selectedDate) {
          setState(() {
            _selectedDate = newDate;
            _bulletinPageUrls = [];
          });
          _fetchBulletinPages(newDate);
        }
      },
    );
  }

  Widget _buildPageView() {
    if (_isLoadingPages) {
      return AspectRatio(aspectRatio: 1, child: const Center(child: CircularProgressIndicator()));
    }
    if (_error != null) {
      return AspectRatio(aspectRatio: 1, child: Center(child: Text(_error!)));
    }
    if (_bulletinPageUrls.isEmpty && !_isLoadingDates) {
      return AspectRatio(aspectRatio: 1, child: const Center(child: Text('선택한 날짜의 주보가 없습니다.')));
    }

    return AspectRatio(
      aspectRatio: 1,
      child: PageView.builder(
        controller: _pageController,
        itemCount: _bulletinPageUrls.length,
        itemBuilder: (context, index) {
          final imageUrl = _bulletinPageUrls[index];
          return GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => Scaffold(
                    appBar: AppBar(title: Text('${_formatDateForDisplay(_selectedDate!)} 주보 (${index + 1}/${_bulletinPageUrls.length})')),
                    body: PhotoView(
                      imageProvider: NetworkImage(imageUrl),
                    ),
                  ),
                ),
              );
            },
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12.0),
              child: Image.network(
                imageUrl,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return const Center(child: CircularProgressIndicator());
                },
                errorBuilder: (context, error, stackTrace) {
                  return const Center(child: Icon(Icons.error));
                },
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPageIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_bulletinPageUrls.length, (index) {
        return Container(
          width: 8.0,
          height: 8.0,
          margin: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 2.0),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _currentPage == index
                ? Theme.of(context).primaryColor
                : Colors.grey.withOpacity(0.5),
          ),
        );
      }),
    );
  }
}
