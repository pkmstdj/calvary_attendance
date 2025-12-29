import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../utils/date_utils.dart'; // 누락된 import 추가

class PrayerDetailArguments {
  final String prayerId;
  final String viewerPhoneNumber; // 현재 보고 있는 사람
  final int viewerPermissionLevel; // 현재 보고 있는 사람의 권한

  PrayerDetailArguments({
    required this.prayerId,
    required this.viewerPhoneNumber,
    required this.viewerPermissionLevel,
  });
}

class PrayerDetailScreen extends StatefulWidget {
  const PrayerDetailScreen({super.key});

  @override
  State<PrayerDetailScreen> createState() => _PrayerDetailScreenState();
}

class _PrayerDetailScreenState extends State<PrayerDetailScreen> {
  late PrayerDetailArguments _args;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      final args = ModalRoute.of(context)!.settings.arguments;
      if (args is PrayerDetailArguments) {
        _args = args;
        _initialized = true;
      } else {
        // Error
      }
    }
  }

  // 기도제목 확인 토글
  Future<void> _toggleChecked(DocumentReference prayerRef, bool isChecked) async {
    final updateData = {
      'checkedBy': isChecked
          ? FieldValue.arrayRemove([_args.viewerPhoneNumber])
          : FieldValue.arrayUnion([_args.viewerPhoneNumber])
    };
    await prayerRef.update(updateData);
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return const Scaffold(body: Center(child: Text('잘못된 접근입니다.')));
    }

    final prayerRef = FirebaseFirestore.instance
        .collection('prayerRequests')
        .doc(_args.prayerId);

    return Scaffold(
      appBar: AppBar(
        title: const Text('기도제목'),
      ),
      body: SafeArea(
        child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: prayerRef.snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError || !snapshot.hasData || !snapshot.data!.exists) {
              return const Center(child: Text('기도제목을 불러올 수 없습니다.'));
            }

            final data = snapshot.data!.data()!;
            final content = data['content']?.toString() ?? '';
            final createdAt = data['createdAt'] as Timestamp?;
            final authorPhone = data['phoneNumber']?.toString() ?? '';
            final authorName = data['authorName']?.toString() ?? '-';
            final authorYouthGroup = data['authorYouthGroup']?.toString() ?? '-';

            final List<dynamic> checkedBy = data['checkedBy'] as List<dynamic>? ?? [];
            final bool isCheckedByMe = checkedBy.contains(_args.viewerPhoneNumber);
            final bool isMyPrayer = authorPhone == _args.viewerPhoneNumber;

            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Text(authorName, style: const TextStyle(fontWeight: FontWeight.bold)),
                                  if (authorYouthGroup.isNotEmpty)
                                    Text(' ($authorYouthGroup)', style: const TextStyle(color: Colors.grey)),
                                ],
                              ),
                              if (createdAt != null)
                                Text(
                                  formatDateTime(createdAt),
                                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                                ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Text(content, style: const TextStyle(fontSize: 16)),
                        ],
                      ),
                    ),
                  ),
                  // 내가 쓴 기도제목이 아닐 경우에만 확인 버튼 표시
                  if (!isMyPrayer)
                    SizedBox(
                      height: 48,
                      child: ElevatedButton.icon(
                        icon: Icon(isCheckedByMe ? Icons.check_circle : Icons.check_circle_outline),
                        label: Text(isCheckedByMe ? '확인됨' : '확인하기'),
                        style: ButtonStyle(
                          backgroundColor: MaterialStateProperty.resolveWith<Color>(
                            (Set<MaterialState> states) {
                              return isCheckedByMe ? Colors.green : Theme.of(context).primaryColor;
                            },
                          ),
                        ),
                        onPressed: () => _toggleChecked(prayerRef, isCheckedByMe),
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
