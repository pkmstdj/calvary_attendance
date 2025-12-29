import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:elegant_notification/elegant_notification.dart';
import 'package:elegant_notification/resources/arrays.dart';
import 'package:elegant_notification/resources/stacked_options.dart';
import 'package:flutter/material.dart';

import '../prayer/prayer_detail_screen.dart';

class PrayerTabScreen extends StatefulWidget {
  final String phoneNumber; // 현재 로그인한 유저의 전화번호
  final int permissionLevel; // 현재 유저의 권한 레벨

  const PrayerTabScreen({
    super.key,
    required this.phoneNumber,
    required this.permissionLevel,
  });

  @override
  State<PrayerTabScreen> createState() => _PrayerTabScreenState();
}

class _PrayerTabScreenState extends State<PrayerTabScreen> {
  final TextEditingController _contentController = TextEditingController();
  bool _isSaving = false;

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

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

  Future<void> _savePrayer() async {
    final content = _contentController.text.trim();
    if (content.isEmpty) {
      ElegantNotification.error(
        title: const Text('오류'),
        description: const Text('기도제목 내용을 입력해 주세요.'),
        width: 280,
        height: 80,
        isDismissable: false,
        animationCurve: Curves.fastOutSlowIn,
        stackedOptions: StackedOptions(
          key: 'top',
          type: StackedType.same,
          itemOffset: const Offset(-5, -5),
        ),
        position: Alignment.topCenter,
        animation: AnimationType.fromTop,
      ).show(context);
      return;
    }

    if (_isSaving) return;
    setState(() {
      _isSaving = true;
    });

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.phoneNumber)
          .get();
      final userData = userDoc.data() ?? {};
      final authorName = (userData['name'] ?? '').toString();
      final authorYouthGroup = (userData['youthGroup'] ?? '').toString();

      await FirebaseFirestore.instance.collection('prayerRequests').add({
        'phoneNumber': widget.phoneNumber,
        'content': content,
        'createdAt': FieldValue.serverTimestamp(),
        'checkedBy': [],
        'authorPermissionLevel': widget.permissionLevel,
        'authorName': authorName,
        'authorYouthGroup': authorYouthGroup,
      });
      _contentController.clear();
      if (mounted) {
        ElegantNotification.success(
          title: const Text('성공'),
          description: const Text('기도제목이 등록되었습니다.'),
          width: 280,
          height: 80,
          isDismissable: false,
          animationCurve: Curves.fastOutSlowIn,
          stackedOptions: StackedOptions(
            key: 'top',
            type: StackedType.same,
            itemOffset: const Offset(-5, -5),
          ),
          position: Alignment.topCenter,
          animation: AnimationType.fromTop,
        ).show(context);
      }
    } catch (_) {
      if (mounted) {
        ElegantNotification.error(
          title: const Text('오류'),
          description: const Text('기도제목 등록 중 오류가 발생했습니다.'),
          width: 280,
          height: 80,
          isDismissable: false,
          animationCurve: Curves.fastOutSlowIn,
          stackedOptions: StackedOptions(
            key: 'top',
            type: StackedType.same,
            itemOffset: const Offset(-5, -5),
          ),
          position: Alignment.topCenter,
          animation: AnimationType.fromTop,
        ).show(context);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  void _openPrayerDetail(String prayerId) {
    Navigator.pushNamed(
      context,
      '/prayerDetail',
      arguments: PrayerDetailArguments(
        prayerId: prayerId,
        viewerPhoneNumber: widget.phoneNumber,
        viewerPermissionLevel: widget.permissionLevel,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final query = FirebaseFirestore.instance
        .collection('prayerRequests')
        .where('phoneNumber', isEqualTo: widget.phoneNumber)
        .orderBy('createdAt', descending: true);

    return SafeArea(
      child: SingleChildScrollView(
        child: Column(
          children: [
            // 입력 영역
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  TextField(
                    controller: _contentController,
                    maxLines: 10,
                    decoration: const InputDecoration(
                      hintText: '기도제목을 입력해 주세요.',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _savePrayer,
                      child: _isSaving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('기도제목 등록'),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // 나의 기도제목 목록
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: query.snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState ==
                    ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                if (snapshot.hasError) {
                  return const Center(
                    child: Text('기도제목을 불러오는 중 오류가 발생했습니다.'),
                  );
                }

                final docs = snapshot.data?.docs ?? [];
                if (docs.isEmpty) {
                  return const Center(
                    child: Text('작성한 기도제목이 없습니다.'),
                  );
                }

                return ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final data = doc.data();
                    final String content =
                        (data['content'] ?? '').toString();
                    final Timestamp? createdAt =
                        data['createdAt'] as Timestamp?;
                    final String dateText =
                        _formatDateTime(createdAt);
                    final List<dynamic> checkedBy = (data['checkedBy'] as List<dynamic>?) ?? [];
                    final bool isChecked = checkedBy.contains(widget.phoneNumber);

                    return ListTile(
                      title: Text(
                        content,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        dateText,
                        style: const TextStyle(fontSize: 12),
                      ),
                      trailing: Icon(
                        isChecked
                            ? Icons.check_circle
                            : Icons.radio_button_unchecked,
                        color: isChecked ? Colors.green : Colors.grey,
                        size: 18,
                      ),
                      onTap: () => _openPrayerDetail(doc.id),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
