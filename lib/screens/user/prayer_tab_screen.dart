import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:elegant_notification/elegant_notification.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../prayer/prayer_detail_screen.dart';

class PrayerTabScreen extends StatefulWidget {
  final String phoneNumber;
  final int permissionLevel;

  const PrayerTabScreen({
    super.key,
    required this.phoneNumber,
    required this.permissionLevel,
  });

  @override
  State<PrayerTabScreen> createState() => _PrayerTabScreenState();
}

class _PrayerTabScreenState extends State<PrayerTabScreen> {
  final TextEditingController _textController = TextEditingController();
  bool _isSaving = false;
  String? _userDocId;
  bool _isLoadingId = true;

  @override
  void initState() {
    super.initState();
    _getUserDocId();
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _getUserDocId() async {
    try {
      final userQuery = await FirebaseFirestore.instance
          .collection('users')
          .where('phoneNumber', isEqualTo: widget.phoneNumber)
          .limit(1)
          .get();
      if (userQuery.docs.isNotEmpty && mounted) {
        setState(() {
          _userDocId = userQuery.docs.first.id;
          _isLoadingId = false;
        });
      } else if (mounted) {
        setState(() => _isLoadingId = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingId = false);
    }
  }

  String _formatDateTime(Timestamp? ts) {
    if (ts == null) return '';
    return DateFormat('yyyy-MM-dd HH:mm').format(ts.toDate());
  }

  Future<void> _savePrayer() async {
    final content = _textController.text.trim();
    if (content.isEmpty) {
      ElegantNotification.error(title: const Text('오류'), description: const Text('기도제목 내용을 입력해 주세요.')).show(context);
      return;
    }
    if (_userDocId == null) {
      ElegantNotification.error(title: const Text('오류'), description: const Text('사용자 정보를 찾을 수 없어 저장할 수 없습니다.')).show(context);
      return;
    }

    if (_isSaving) return;
    setState(() => _isSaving = true);

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(_userDocId)
          .collection('prayerRequests')
          .add({
        'text': content,
        'createdAt': FieldValue.serverTimestamp(),
        'isChecked': false,
      });

      _textController.clear();
      if (mounted) {
        ElegantNotification.success(title: const Text('성공'), description: const Text('기도제목이 등록되었습니다.')).show(context);
      }
    } catch (_) {
      if (mounted) {
        ElegantNotification.error(title: const Text('오류'), description: const Text('기도제목 등록 중 오류가 발생했습니다.')).show(context);
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _openPrayerDetail(String prayerDocId, String text, String? date) {
    if (_userDocId == null) return;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (context) => const PrayerDetailScreen(),
      settings: RouteSettings(
        arguments: PrayerDetailScreenArguments(
          userDocId: _userDocId!,
          prayerDocId: prayerDocId,
          text: text,
          date: date,
          isOwner: true,
        ),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingId) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_userDocId == null) {
      return const Center(child: Text('사용자 정보를 찾을 수 없습니다.'));
    }

    final query = FirebaseFirestore.instance
        .collection('users')
        .doc(_userDocId)
        .collection('prayerRequests')
        .orderBy('createdAt', descending: true);

    return SafeArea(
      child: SingleChildScrollView(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  TextField(
                    controller: _textController,
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
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: query.snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return const Center(child: Text('기도제목을 불러오는 중 오류가 발생했습니다.'));
                }
                final docs = snapshot.data?.docs ?? [];
                if (docs.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(24.0),
                    child: Center(child: Text('작성한 기도제목이 없습니다.')),
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
                    final String text = (data['text'] ?? '').toString();
                    final Timestamp? createdAt = data['createdAt'] as Timestamp?;
                    final String? dateText = createdAt != null ? _formatDateTime(createdAt) : null;
                    final bool isChecked = data['isChecked'] as bool? ?? false;

                    return ListTile(
                      title: Text(
                        text,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(dateText ?? '', style: const TextStyle(fontSize: 12)),
                      trailing: Icon(
                        isChecked ? Icons.check_circle : Icons.radio_button_unchecked,
                        color: isChecked ? Colors.green : Colors.grey,
                        size: 18,
                      ),
                      onTap: () => _openPrayerDetail(doc.id, text, dateText),
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
