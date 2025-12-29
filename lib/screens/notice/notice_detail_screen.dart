import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class NoticeDetailArguments {
  final String noticeId;
  final String viewerPhoneNumber;
  final int viewerPermissionLevel;

  NoticeDetailArguments({
    required this.noticeId,
    required this.viewerPhoneNumber,
    required this.viewerPermissionLevel,
  });
}

class NoticeDetailScreen extends StatelessWidget {
  const NoticeDetailScreen({super.key});

  String _formatDateTime(Timestamp? ts) {
    if (ts == null) return '';
    final dt = ts.toDate();
    final y = dt.year.toString();
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final h = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '$y-$m-$d $h:$min';
  }

  void _openEdit(
    BuildContext context,
    String noticeId,
    String phoneNumber,
    int viewerPermissionLevel,
    Map<String, dynamic> data,
  ) {
    Navigator.pushNamed(
      context,
      '/noticeForm',
      arguments: NoticeFormArguments(
        phoneNumber: phoneNumber,
        viewerPermissionLevel: viewerPermissionLevel,
        isAdminNoticeDefault: (data['isAdminNotice'] as bool?) ?? false,
        isEdit: true,
        noticeId: noticeId,
        initialTitle: (data['title'] ?? '').toString(),
        initialContent: (data['content'] ?? '').toString(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)!.settings.arguments;
    if (args is! NoticeDetailArguments) {
      return const Scaffold(
        body: Center(child: Text('잘못된 접근입니다.')),
      );
    }

    final docRef =
        FirebaseFirestore.instance.collection('notices').doc(args.noticeId);

    return Scaffold(
      appBar: AppBar(
        title: const Text('공지사항'),
      ),
      body: SafeArea(
        child: FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          future: docRef.get(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Center(
                child: Text('공지사항을 불러오는 중 오류: ${snapshot.error}'),
              );
            }

            if (!snapshot.hasData || !snapshot.data!.exists) {
              return const Center(
                child: Text('공지사항을 찾을 수 없습니다.'),
              );
            }

            final data = snapshot.data!.data()!;
            final String title = (data['title'] ?? '제목 없음').toString();
            final String content = (data['content'] ?? '').toString();
            final Timestamp? createdAt = data['createdAt'] as Timestamp?;
            final Timestamp? updatedAt = data['updatedAt'] as Timestamp?;
            final String createdText = _formatDateTime(createdAt);
            final String updatedText = _formatDateTime(updatedAt);
            final bool hasEdited = (data['hasEdited'] as bool?) ??
                ((updatedAt != null && createdAt != null)
                    ? updatedAt.toDate().isAfter(createdAt.toDate())
                    : false);

            final String authorPhone =
                (data['authorPhoneNumber'] ?? '').toString();
            final int authorPermission =
                (data['authorPermissionLevel'] ?? 5) as int;

            final bool canEdit = (args.viewerPhoneNumber == authorPhone) ||
                (args.viewerPermissionLevel < authorPermission);

            return Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      if (hasEdited)
                        const Padding(
                          padding: EdgeInsets.only(left: 4),
                          child: Text(
                            '(수정)',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (createdText.isNotEmpty)
                    Text(
                      '작성: $createdText',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                  if (updatedText.isNotEmpty)
                    Text(
                      '마지막 수정: $updatedText',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.brown.shade200,
                        ),
                      ),
                      padding: const EdgeInsets.all(16),
                      child: SingleChildScrollView(
                        child: Text(
                          content,
                          style: const TextStyle(fontSize: 15),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (canEdit)
                    SizedBox(
                      height: 44,
                      child: ElevatedButton(
                        onPressed: () => _openEdit(
                          context,
                          args.noticeId,
                          args.viewerPhoneNumber,
                          args.viewerPermissionLevel,
                          data,
                        ),
                        child: const Text(
                          '수정하기',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class NoticeFormArguments {
  final String phoneNumber;
  final int viewerPermissionLevel;
  final bool isAdminNoticeDefault;
  final bool isEdit;
  final String? noticeId;
  final String? initialTitle;
  final String? initialContent;

  NoticeFormArguments({
    required this.phoneNumber,
    required this.viewerPermissionLevel,
    required this.isAdminNoticeDefault,
    required this.isEdit,
    required this.noticeId,
    required this.initialTitle,
    required this.initialContent,
  });
}
