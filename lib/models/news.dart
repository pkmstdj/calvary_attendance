class News {
  final String title;
  final String? description;
  final String url;

  News({required this.title, this.description, required this.url});

  factory News.fromJson(Map<String, dynamic> json) {
    return News(
      title: json['title'] as String,
      description: json['description'] as String?,
      url: json['url'] as String,
    );
  }
}
