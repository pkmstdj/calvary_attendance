import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import '../../models/news.dart';

const String _apiKey = '3b91219b71394468b4e78593a12513f1';

class NewsCard extends StatefulWidget {
  final String? phoneNumber; // phoneNumber를 nullable로 변경

  const NewsCard({super.key, this.phoneNumber});

  @override
  State<NewsCard> createState() => _NewsCardState();
}

class _NewsCardState extends State<NewsCard> {
  late Future<List<News>> _newsFuture;

  @override
  void initState() {
    super.initState();
    // phoneNumber가 null이 아닐 때만 API 호출
    if (widget.phoneNumber != null) {
      _newsFuture = _fetchNews();
    } else {
      _newsFuture = Future.value([]); // 빈 리스트를 반환하는 Future
    }
  }

  Future<List<News>> _fetchNews() async {
    const url = 'https://newsapi.org/v2/top-headlines?country=kr&category=general&apiKey=$_apiKey';
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        final articles = data['articles'] as List;
        return articles.map((json) => News.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load news');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error loading news: $e');
      }
      // setState() called after dispose() 에러 방지를 위해 mounted 확인
      if (mounted) {
        // 에러가 발생했을 때 사용자에게 피드백을 주기 위해, 빈 리스트를 반환하거나 다른 처리를 할 수 있습니다.
        // 여기서는 그냥 빈 리스트를 반환합니다.
        setState(() {});
      }
      return [];
    }
  }


  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.inAppBrowserView)) {
      throw Exception('Could not launch $url');
    }
  }

  @override
  Widget build(BuildContext context) {
    // phoneNumber가 null이면 뉴스 카드를 표시하지 않음
    if (widget.phoneNumber == null) {
      return const SizedBox.shrink();
    }

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '주요 뉴스',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            FutureBuilder<List<News>>(
              future: _newsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(child: Text('뉴스를 불러올 수 없습니다.'));
                }
                final newsList = snapshot.data!;
                return SizedBox(
                  height: 120, // 높이를 고정하여 UI 안정성 확보
                  child: ListView.separated(
                    itemCount: newsList.length > 5 ? 5 : newsList.length, // 최대 5개만 표시
                    separatorBuilder: (context, index) => const Divider(),
                    itemBuilder: (context, index) {
                      final news = newsList[index];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          news.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: news.description != null
                            ? Text(
                                news.description!,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              )
                            : null,
                        onTap: () => _launchUrl(news.url),
                      );
                    },
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
