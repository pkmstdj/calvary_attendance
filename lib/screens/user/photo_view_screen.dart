
import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';

class PhotoViewScreen extends StatefulWidget {
  final List<String> imageUrls;
  final int initialIndex;

  const PhotoViewScreen({
    super.key,
    required this.imageUrls,
    this.initialIndex = 0,
  });

  @override
  State<PhotoViewScreen> createState() => _PhotoViewScreenState();
}

class _PhotoViewScreenState extends State<PhotoViewScreen> {
  late final PageController _pageController;
  bool _appBarVisible = true;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _toggleAppBar() {
    setState(() {
      _appBarVisible = !_appBarVisible;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _appBarVisible
          ? AppBar(
              backgroundColor: Colors.black,
              elevation: 0,
            )
          : null,
      body: GestureDetector(
        onTap: _toggleAppBar,
        child: PhotoViewGallery.builder(
          itemCount: widget.imageUrls.length,
          pageController: _pageController,
          builder: (context, index) {
            return PhotoViewGalleryPageOptions(
              imageProvider: NetworkImage(widget.imageUrls[index]),
              minScale: PhotoViewComputedScale.contained,
              maxScale: PhotoViewComputedScale.covered * 2,
            );
          },
          loadingBuilder: (context, event) => const Center(
            child: CircularProgressIndicator(),
          ),
          backgroundDecoration: const BoxDecoration(
            color: Colors.black,
          ),
        ),
      ),
    );
  }
}
