import 'package:cached_network_image/cached_network_image.dart';
import 'package:calvary_attendance/screens/common/full_screen_image_viewer.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';

class NewsCard extends StatefulWidget {
  final List<String> imageUrls;
  final String? date;

  const NewsCard({
    super.key,
    required this.imageUrls,
    this.date,
  });

  @override
  State<NewsCard> createState() => _NewsCardState();
}

class _NewsCardState extends State<NewsCard> {
  int _currentImageIndex = 0;
  final CarouselSliderController _carouselController = CarouselSliderController();
  late List<String> _sortedImageUrls;

  @override
  void initState() {
    super.initState();
    _sortedImageUrls = _sortImageUrls(widget.imageUrls);
  }

  @override
  void didUpdateWidget(covariant NewsCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.imageUrls != oldWidget.imageUrls) {
      _sortedImageUrls = _sortImageUrls(widget.imageUrls);
    }
  }

  int _extractNumberFromUrl(String url) {
    try {
      final Uri uri = Uri.parse(url);
      final String fileName = uri.pathSegments.last; // URL에서 파일 이름 부분 추출
      final RegExp regExp = RegExp(r'news_(\d+)\.jpg');
      final match = regExp.firstMatch(fileName);
      if (match != null && match.group(1) != null) {
        return int.parse(match.group(1)!);
      }
    } catch (e) {
      // 파싱 실패 시 기본값 반환
    }
    return 999; // 오류 발생 시 맨 뒤로 정렬
  }

  List<String> _sortImageUrls(List<String> urls) {
    final List<String> sortedList = List.from(urls);
    sortedList.sort((a, b) => _extractNumberFromUrl(a).compareTo(_extractNumberFromUrl(b)));
    return sortedList;
  }

  @override
  Widget build(BuildContext context) {
    if (_sortedImageUrls.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        CarouselSlider.builder(
          carouselController: _carouselController,
          itemCount: _sortedImageUrls.length,
          itemBuilder: (context, index, realIndex) {
            final imageUrl = _sortedImageUrls[index];
            return GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => FullScreenImageViewer(
                      imageUrl: imageUrl,
                      title: '20${widget.date}',
                    ),
                  ),
                );
              },
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12.0),
                child: CachedNetworkImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.contain,
                  placeholder: (context, url) =>
                      const Center(child: CircularProgressIndicator()),
                  errorWidget: (context, url, error) => const Icon(Icons.error),
                ),
              ),
            );
          },
          options: CarouselOptions(
            aspectRatio: 1,
            viewportFraction: 1.0,
            enableInfiniteScroll: false,
            onPageChanged: (index, reason) {
              setState(() {
                _currentImageIndex = index;
              });
            },
          ),
        ),
        if (_sortedImageUrls.length > 1)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: _sortedImageUrls.asMap().entries.map((entry) {
              return GestureDetector(
                onTap: () => _carouselController.animateToPage(entry.key),
                child: Container(
                  width: 8.0,
                  height: 8.0,
                  margin:
                      const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.black
                        .withOpacity(_currentImageIndex == entry.key ? 0.9 : 0.4),
                  ),
                ),
              );
            }).toList(),
          ),
      ],
    );
  }
}
