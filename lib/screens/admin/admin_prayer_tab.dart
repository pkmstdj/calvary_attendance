
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../utils/phone_utils.dart';
import 'admin_user_profile_screen.dart';

class AdminPrayerTab extends StatefulWidget {
  final String phoneNumber;      // 관리자 전화번호
  final int permissionLevel;     // 관리자 권한

  const AdminPrayerTab({
    super.key,
    required this.phoneNumber,
    required this.permissionLevel,
  });

  @override
  State<AdminPrayerTab> createState() => _AdminPrayerTabState();
}

class _AdminPrayerTabState extends State<AdminPrayerTab> {
  bool _showOnlyUnchecked = false;

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

  @override
  Widget build(BuildContext context) {
    final query = FirebaseFirestore.instance
        .collection('prayerRequests')
        .orderBy('createdAt', descending: true);

    return Scaffold(
      appBar: AppBar(
        title: const Text('기도제목 관리'),
        actions: [
          Row(
            children: [
              const Text(
                '미확인만',
                style: TextStyle(fontSize: 12),
              ),
              Switch(
                value: _showOnlyUnchecked,
                onChanged: (v) {
                  setState(() {
                    _showOnlyUnchecked = v;
                  });
                },
              ),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: query.snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
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
                child: Text('등록된 기도제목이 없습니다.'),
              );
            }

            // 전화번호별 가장 최근 기도제목만 추려내기
            final Map<String, QueryDocumentSnapshot<Map<String, dynamic>>>
                latestByPhone = {};

            for (final doc in docs) {
              final data = doc.data();
              final phone =
                  (data['phoneNumber'] ?? '').toString();
              if (phone.isEmpty) continue;

              final bool isChecked =
                  (data['isChecked'] as bool?) ?? false;
              if (_showOnlyUnchecked && isChecked) {
                continue;
              }

              if (!latestByPhone.containsKey(phone)) {
                latestByPhone[phone] = doc;
              }
            }

            final entries = latestByPhone.values.toList();
            if (entries.isEmpty) {
              return const Center(
                child: Text('조건에 맞는 기도제목이 없습니다.'),
              );
            }

            return ListView.separated(
              itemCount: entries.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final doc = entries[index];
                final data = doc.data();
                final phone =
                    (data['phoneNumber'] ?? '').toString();
                final name =
                    (data['authorName'] ?? '이름 없음').toString();
                final youthGroup =
                    (data['authorYouthGroup'] ?? '').toString();
                final content =
                    (data['content'] ?? '').toString();
                final createdAt =
                    data['createdAt'] as Timestamp?;
                final dateText = _formatDateTime(createdAt);
                final bool isChecked =
                    (data['isChecked'] as bool?) ?? false;

                return ListTile(
                  title: Row(
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (youthGroup.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(left: 4),
                          child: Text(
                            youthGroup,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.brown,
                            ),
                          ),
                        ),
                    ],
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        content,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              formatPhoneNumber(phone),
                              style: const TextStyle(fontSize: 11),
                            ),
                          ),
                          Text(
                            dateText,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  trailing: Icon(
                    isChecked
                        ? Icons.check_circle
                        : Icons.radio_button_unchecked,
                    color: isChecked ? Colors.green : Colors.redAccent,
                    size: 18,
                  ),
                  onTap: () {
                    Navigator.pushNamed(
                      context,
                      '/adminUserProfile',
                      arguments: AdminUserProfileArguments(
                        targetPhoneNumber: phone,
                        viewerPhoneNumber: widget.phoneNumber,
                        viewerPermissionLevel: widget.permissionLevel,
                      ),
                    );
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }
}
