import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MediaTeamTab extends StatefulWidget {
  const MediaTeamTab({super.key});

  @override
  State<MediaTeamTab> createState() => _MediaTeamTabState();
}

class _MediaTeamTabState extends State<MediaTeamTab> {
  DateTime _selectedDate = DateTime.now();
  final ImagePicker _picker = ImagePicker();
  List<XFile> _selectedImages = [];
  bool _isUploading = false;

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2101),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _pickImages() async {
    final List<XFile> images = await _picker.pickMultiImage();
    setState(() {
      _selectedImages = images;
    });
  }

  Future<String?> _getUserIdFromPhoneNumber() async {
    final prefs = await SharedPreferences.getInstance();
    final phoneNumber = prefs.getString('savedPhoneNumber');
    if (phoneNumber == null) return null;

    final querySnapshot = await FirebaseFirestore.instance
        .collection('users')
        .where('phoneNumber', isEqualTo: phoneNumber)
        .limit(1)
        .get();

    if (querySnapshot.docs.isNotEmpty) {
      return querySnapshot.docs.first.id;
    }
    return null;
  }

  Future<void> _uploadImages() async {
    if (_selectedImages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('사진을 선택해주세요.')),
      );
      return;
    }

    final uploaderId = await _getUserIdFromPhoneNumber();
    if (uploaderId == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('사용자 정보를 찾을 수 없습니다. 다시 로그인 해주세요.')),
      );
      return;
    }

    setState(() {
      _isUploading = true;
    });

    try {
      final String formattedDate = DateFormat('yyMMdd').format(_selectedDate);
      final List<String> downloadUrls = [];

      // Loop with index to create filenames like news_0.jpg, news_1.jpg
      for (int i = 0; i < _selectedImages.length; i++) {
        final image = _selectedImages[i];
        final String fileName = 'news_$i.jpg';
        final Reference storageRef =
            FirebaseStorage.instance.ref().child('news/$formattedDate/$fileName');

        final UploadTask uploadTask = storageRef.putFile(File(image.path));
        final TaskSnapshot snapshot = await uploadTask;
        final String downloadUrl = await snapshot.ref.getDownloadURL();
        downloadUrls.add(downloadUrl);
      }

      if (downloadUrls.isNotEmpty) {
        await FirebaseFirestore.instance.collection('news').add({
          'imageUrls': downloadUrls,
          'timestamp': FieldValue.serverTimestamp(),
          'approved': false,
          'date': formattedDate,
          'uploaderId': uploaderId,
        });
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('사진이 업로드 요청되었습니다.')),
      );
      setState(() {
        _selectedImages = [];
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('업로드 실패: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          // 하단 여백 추가
          padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 80.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('날짜 선택', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(DateFormat('yyyy년 MM월 dd일').format(_selectedDate)),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () => _selectDate(context),
                    child: const Text('날짜 변경'),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Text('사진 선택', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: _pickImages,
                child: const Text('사진 선택하기'),
              ),
              const SizedBox(height: 16),
              _selectedImages.isNotEmpty
                  ? GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate:
                const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 4,
                  mainAxisSpacing: 4,
                ),
                itemCount: _selectedImages.length,
                itemBuilder: (context, index) {
                  return Image.file(
                    File(_selectedImages[index].path),
                    fit: BoxFit.cover,
                  );
                },
              )
                  : const Text('선택된 사진이 없습니다.'),
              const SizedBox(height: 24),
              if (_isUploading)
                const Center(child: CircularProgressIndicator())
              else
                Center(
                  child: ElevatedButton(
                    onPressed: _uploadImages,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 40, vertical: 16),
                    ),
                    child: const Text('업로드'),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
