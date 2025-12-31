import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';

class FullScreenImageViewer extends StatefulWidget {
  final String imageUrl;
  final String title;

  const FullScreenImageViewer({
    super.key,
    required this.imageUrl,
    required this.title,
  });

  @override
  State<FullScreenImageViewer> createState() => _FullScreenImageViewerState();
}

class _FullScreenImageViewerState extends State<FullScreenImageViewer> {
  bool _showAppBar = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          GestureDetector(
            onTap: () {
              setState(() {
                _showAppBar = !_showAppBar;
              });
            },
            child: PhotoView(
              imageProvider: NetworkImage(widget.imageUrl),
              minScale: PhotoViewComputedScale.contained,
              maxScale: PhotoViewComputedScale.covered * 2,
              heroAttributes: PhotoViewHeroAttributes(tag: widget.imageUrl),
            ),
          ),
          if (_showAppBar)
            AnimatedPositioned(
              duration: const Duration(milliseconds: 300),
              top: _showAppBar ? 0 : -kToolbarHeight,
              left: 0,
              right: 0,
              child: AppBar(
                title: Text(widget.title),
                backgroundColor: Colors.white.withOpacity(0.8),
                elevation: 0,
              ),
            ),
        ],
      ),
    );
  }
}
