
import 'dart:async';

import 'package:carousel_slider/carousel_slider.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart' hide CarouselController;
import 'package:intl/intl.dart';

import './photo_view_screen.dart';

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
  final FirebaseStorage _storage = FirebaseStorage.instance;
  List<String> _bulletinDates = [];
  String? _selectedDate;
  Map<String, List<String>> _bulletinImages = {};
  bool _isLoading = true;
  int _currentCarouselIndex = 0;
  final CSCarouselController _carouselController = CSCarouselController();

  @override
  void initState() {
    super.initState();
    // LoadingScreen에서 로그인 상태를 보장해주므로, 바로 데이터를 가져옵니다.
    _fetchBulletins();
  }

  Future<void> _fetchBulletins() async {
    try {
      final ListResult result = await _storage.ref('news').listAll();
      final allFiles = result.items;
      print('Found \${allFiles.length} files in /news/. Processing...');
      Map<String, List<String>> bulletins = {};
      final RegExp dateRegExp = RegExp(r'news_(\d{6})');

      for (var file in allFiles) {
        final match = dateRegExp.firstMatch(file.name);
        if (match != null) {
          final dateStr = match.group(1)!;
          print('Found bulletin for date: \$dateStr from file: \${file.name}');

          if (bulletins.containsKey(dateStr)) {
            bulletins[dateStr]!.add(await file.getDownloadURL());
          } else {
            bulletins[dateStr] = [await file.getDownloadURL()];
          }
        } else {
          print('Skipping file with non-matching name: \${file.name}');
        }
      }
      print('Processed \${bulletins.length} unique dates.');
      if (bulletins.isEmpty && allFiles.isNotEmpty) {
        print('WARNING: No files matched the expected naming convention \'news_yymmdd_...\'');
      }

      final sortedDates = bulletins.keys.toList()
        ..sort((a, b) => b.compareTo(a));

      if (mounted) {
        setState(() {
          _bulletinDates = sortedDates.take(3).toList();
          _bulletinImages = bulletins;
          if (_bulletinDates.isNotEmpty) {
            _selectedDate = _bulletinDates[0];
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error fetching bulletins: \$e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String _formatDate(String yymmdd) {
    if (yymmdd.length != 6) {
      return yymmdd;
    }
    try {
      final yy = yymmdd.substring(0, 2);
      final mm = yymmdd.substring(2, 4);
      final dd = yymmdd.substring(4, 6);
      return '$yy년 $mm월 $dd일';
    } catch (e) {
      return yymmdd; // fallback
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _bulletinDates.isEmpty
              ? const Center(child: Text('주보가 없습니다.'))
              : ListView(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  children: [buildBulletinCard()],
                ),
    );
  }

  Widget buildBulletinCard() {
    List<String> images = _bulletinImages[_selectedDate] ?? [];

    return Card(
      margin: const EdgeInsets.all(16.0),
      elevation: 4.0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
      child: Column(
        children: [
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('순전한 주보',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                DropdownButton<String>(
                  value: _selectedDate,
                  items: _bulletinDates.map((String date) {
                    return DropdownMenuItem<String>(
                      value: date,
                      child: Text(_formatDate(date)),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    setState(() {
                      _selectedDate = newValue;
                      _currentCarouselIndex = 0;
                      final newImages = _bulletinImages[newValue] ?? [];
                      if (newImages.isNotEmpty) {
                        _carouselController.jumpToPage(0);
                      }
                    });
                  },
                ),
              ],
            ),
          ),
          if (images.isNotEmpty)
            Column(
              children: [
                CarouselSlider.builder(
                  carouselController: _carouselController,
                  itemCount: images.length,
                  itemBuilder: (context, index, realIndex) {
                    return GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => PhotoViewScreen(
                              imageUrls: images,
                              initialIndex: index,
                            ),
                          ),
                        );
                      },
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8.0),
                        child: Image.network(
                          images[index],
                          fit: BoxFit.cover,
                          loadingBuilder: (BuildContext context, Widget child,
                              ImageChunkEvent? loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Center(
                              child: CircularProgressIndicator(
                                value: loadingProgress.expectedTotalBytes !=
                                        null
                                    ? loadingProgress.cumulativeBytesLoaded /
                                        loadingProgress.expectedTotalBytes!
                                    : null,
                              ),
                            );
                          },
                        ),
                      ),
                    );
                  },
                  options: CarouselOptions(
                    height: 400,
                    viewportFraction: 0.9,
                    enableInfiniteScroll: false,
                    enlargeCenterPage: true,
                    onPageChanged: (index, reason) {
                      setState(() {
                        _currentCarouselIndex = index;
                      });
                    },
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: images.asMap().entries.map((entry) {
                    return GestureDetector(
                      onTap: () => _carouselController.animateToPage(entry.key),
                      child: Container(
                        width: 8.0,
                        height: 8.0,
                        margin: const EdgeInsets.symmetric(
                            vertical: 10.0, horizontal: 4.0),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: (Theme.of(context).brightness ==
                                  Brightness.dark
                                  ? Colors.white
                                  : Colors.black)
                              .withOpacity(
                                  _currentCarouselIndex == entry.key ? 0.9 : 0.4),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            )
          else
            const SizedBox(
              height: 400,
              child: Center(child: Text('이미지를 불러올 수 없습니다.')),
            ),
        ],
      ),
    );
  }
}
