import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../utils/phone_utils.dart';

class AdminAdminTab extends StatefulWidget {
  final String phoneNumber;
  final int permissionLevel;

  const AdminAdminTab({
    super.key,
    required this.phoneNumber,
    required this.permissionLevel,
  });

  @override
  State<AdminAdminTab> createState() => _AdminAdminTabState();
}

class _AdminAdminTabState extends State<AdminAdminTab> {
  // 사용자를 승인하는 함수 (권한을 3으로 변경)
  Future<void> _approveUser(String docId) async {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(docId)
        .update({'permissionLevel': 3});
  }

  // 사용자를 거절(삭제)하는 함수
  Future<void> _rejectUser(String docId) async {
    await FirebaseFirestore.instance.collection('users').doc(docId).delete();
  }

  // 소식(사진)을 승인하는 함수
  Future<void> _approveNews(String docId) async {
    await FirebaseFirestore.instance
        .collection('news')
        .doc(docId)
        .update({'approved': true});
  }

  // 소식(사진)을 거절(삭제)하는 함수
  Future<void> _rejectNews(String docId, List<String> imageUrls) async {
    try {
      // Firestore 문서 삭제
      await FirebaseFirestore.instance.collection('news').doc(docId).delete();
      // Storage에서 모든 이미지 삭제
      for (final url in imageUrls) {
        try {
          await FirebaseStorage.instance.refFromURL(url).delete();
        } catch (e) {
          // 개별 이미지 삭제 실패는 무시하고 계속 진행
        }
      }
    } catch (e) {
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('삭제 중 오류 발생: $e')),
      );
    }
  }

  // 교육훈련팀 문항을 승인하는 함수
  Future<void> _approveEducation(String docId) async {
    await FirebaseFirestore.instance
        .collection('education')
        .doc(docId)
        .update({'approved': true});
  }

  // 교육훈련팀 문항을 거절(삭제)하는 함수
  Future<void> _rejectEducation(String docId) async {
    await FirebaseFirestore.instance.collection('education').doc(docId).delete();
  }

  Future<String> _getUserName(String userId) async {
    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
      if (userDoc.exists) {
        return userDoc.data()?['name'] ?? '알 수 없음';
      }
    } catch (e) {
      return '알 수 없음';
    }
    return '알 수 없음';
  }


  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('관리자 승인'),
          bottom: const TabBar(
            tabs: [
              Tab(text: '가입 승인'),
              Tab(text: '소식 승인'),
              Tab(text: '문항 승인'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildUserApprovalList(),
            _buildNewsApprovalList(),
            _buildEducationApprovalList(),
          ],
        ),
      ),
    );
  }

  Widget _buildUserApprovalList() {
    final pendingQuery = FirebaseFirestore.instance
        .collection('users')
        .where('permissionLevel', isEqualTo: 4)
        .orderBy('name');

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: pendingQuery.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return RefreshIndicator(
            onRefresh: () async {
               setState(() {});
            },
            child: SingleChildScrollView(
               physics: const AlwaysScrollableScrollPhysics(),
               child: SizedBox(
                   height: MediaQuery.of(context).size.height * 0.7,
                   child: const Center(child: Text('목록을 불러오는 중 오류가 발생했습니다.'))
               ),
            ),
          );
        }

        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return RefreshIndicator(
            onRefresh: () async {
               setState(() {});
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: SizedBox(
                  height: MediaQuery.of(context).size.height * 0.7,
                  child: const Center(child: Text('승인 대기 중인 사용자가 없습니다.'))
              ),
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            setState(() {});
          },
          child: ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final userDoc = docs[index];
              final data = userDoc.data();
              final name = (data['name'] ?? '이름 없음').toString();
              final phone = (data['phoneNumber'] ?? '').toString();
              final birthDate = (data['birthDate'] ?? '정보 없음').toString();
              final classYear = (data['classYear'] ?? '??').toString();
              
              final formattedPhone = formatPhoneNumber(phone);

              return ListTile(
                title: Text('$name ($classYear기)'),
                subtitle: Text('$birthDate / $formattedPhone'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextButton(
                      child: const Text('승인'),
                      onPressed: () => _approveUser(userDoc.id),
                    ),
                    const SizedBox(width: 4),
                    TextButton(
                      style: TextButton.styleFrom(foregroundColor: Colors.red),
                      child: const Text('거절'),
                      onPressed: () => _rejectUser(userDoc.id),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildNewsApprovalList() {
    final pendingNewsQuery = FirebaseFirestore.instance
        .collection('news')
        .where('approved', isEqualTo: false)
        .orderBy('timestamp', descending: true);

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: pendingNewsQuery.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return RefreshIndicator(
            onRefresh: () async {
               setState(() {});
            },
            child: SingleChildScrollView(
               physics: const AlwaysScrollableScrollPhysics(),
               child: SizedBox(
                   height: MediaQuery.of(context).size.height * 0.7,
                   child: const Center(child: Text('목록을 불러오는 중 오류가 발생했습니다.'))
               ),
            ),
          );
        }

        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return RefreshIndicator(
            onRefresh: () async {
               setState(() {});
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: SizedBox(
                  height: MediaQuery.of(context).size.height * 0.7,
                  child: const Center(child: Text('승인 대기 중인 소식이 없습니다.'))
              ),
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            setState(() {});
          },
          child: ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final newsDoc = docs[index];
              final data = newsDoc.data();
              final imageUrls = List<String>.from(data['imageUrls'] ?? []);
              final uploaderId = data['uploaderId'] as String?;
              final date = data['date'] as String?;

              if (imageUrls.isEmpty) {
                return const SizedBox.shrink(); // 이미지가 없는 항목은 표시하지 않음
              }

              return FutureBuilder<String>(
                future: uploaderId != null ? _getUserName(uploaderId) : Future.value('알 수 없음'),
                builder: (context, userNameSnapshot) {
                  final uploaderName = userNameSnapshot.data ?? '로딩 중...';
                  return ListTile(
                    leading: SizedBox(
                      width: 80,
                      height: 80,
                      child: CachedNetworkImage(
                        imageUrl: imageUrls.first,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => const Center(child: CircularProgressIndicator()),
                        errorWidget: (context, url, error) => const Icon(Icons.error),
                      ),
                    ),
                    title: Text('날짜: 20$date (${imageUrls.length}장)'),
                    subtitle: Text('업로더: $uploaderName'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextButton(
                          child: const Text('승인'),
                          onPressed: () => _approveNews(newsDoc.id),
                        ),
                        const SizedBox(width: 4),
                        TextButton(
                          style: TextButton.styleFrom(foregroundColor: Colors.red),
                          child: const Text('거절'),
                          onPressed: () => _rejectNews(newsDoc.id, imageUrls),
                        ),
                      ],
                    ),
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: Text('이미지 상세 보기 (20$date)'),
                          content: SizedBox(
                            width: double.maxFinite,
                            child: GridView.builder(
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                crossAxisSpacing: 4,
                                mainAxisSpacing: 4,
                              ),
                              itemCount: imageUrls.length,
                              itemBuilder: (context, imgIndex) {
                                return CachedNetworkImage(
                                  imageUrl: imageUrls[imgIndex],
                                  fit: BoxFit.cover,
                                  placeholder: (context, url) => const Center(child: CircularProgressIndicator()),
                                  errorWidget: (context, url, error) => const Icon(Icons.error),
                                );
                              },
                            ),
                          ),
                          actions: [
                            TextButton(
                              child: const Text('닫기'),
                              onPressed: () => Navigator.of(context).pop(),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildEducationApprovalList() {
    final pendingEducationQuery = FirebaseFirestore.instance
        .collection('education')
        .where('approved', isEqualTo: false)
        .orderBy('timestamp', descending: true);

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: pendingEducationQuery.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return RefreshIndicator(
            onRefresh: () async {
               setState(() {});
            },
            child: SingleChildScrollView(
               physics: const AlwaysScrollableScrollPhysics(),
               child: SizedBox(
                   height: MediaQuery.of(context).size.height * 0.7,
                   child: const Center(child: Text('목록을 불러오는 중 오류가 발생했습니다.'))
               ),
            ),
          );
        }

        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return RefreshIndicator(
            onRefresh: () async {
               setState(() {});
            },
            child: SingleChildScrollView(
               physics: const AlwaysScrollableScrollPhysics(),
               child: SizedBox(
                   height: MediaQuery.of(context).size.height * 0.7,
                   child: const Center(child: Text('승인 대기 중인 문항이 없습니다.'))
               ),
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            setState(() {});
          },
          child: ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final educationDoc = docs[index];
              final data = educationDoc.data();
              final uploaderId = data['uploaderId'] as String?;
              final date = data['date'] as String?;
              final questions = List<String>.from(data['questions'] ?? []);

              return FutureBuilder<String>(
                future: uploaderId != null ? _getUserName(uploaderId) : Future.value('알 수 없음'),
                builder: (context, userNameSnapshot) {
                  final uploaderName = userNameSnapshot.data ?? '로딩 중...';
                  return ListTile(
                    title: Text('날짜: 20$date'),
                    subtitle: Text('업로더: $uploaderName'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextButton(
                          child: const Text('승인'),
                          onPressed: () => _approveEducation(educationDoc.id),
                        ),
                        const SizedBox(width: 4),
                        TextButton(
                          style: TextButton.styleFrom(foregroundColor: Colors.red),
                          child: const Text('거절'),
                          onPressed: () => _rejectEducation(educationDoc.id),
                        ),
                      ],
                    ),
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: Text('문항 상세 정보 (20$date)'),
                          content: SizedBox(
                            width: double.maxFinite,
                            child: ListView.builder(
                              shrinkWrap: true,
                              itemCount: questions.length,
                              itemBuilder: (context, qIndex) {
                                return ListTile(
                                  leading: Text('${qIndex + 1}.'),
                                  title: Text(questions[qIndex]),
                                );
                              },
                            ),
                          ),
                          actions: [
                            TextButton(
                              child: const Text('닫기'),
                              onPressed: () => Navigator.of(context).pop(),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              );
            },
          ),
        );
      },
    );
  }
}
