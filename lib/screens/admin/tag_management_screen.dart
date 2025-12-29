import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class TagManagementScreen extends StatefulWidget {
  const TagManagementScreen({super.key});

  @override
  State<TagManagementScreen> createState() => _TagManagementScreenState();
}

class _TagManagementScreenState extends State<TagManagementScreen> {
  final TextEditingController _tagController = TextEditingController();

  @override
  void dispose() {
    _tagController.dispose();
    super.dispose();
  }

  Future<void> _addTag() async {
    final tagName = _tagController.text.trim();
    if (tagName.isEmpty) return;

    await FirebaseFirestore.instance.collection('tags').add({
      'name': tagName,
      'isSpecialTeam': false, // 특별 팀 여부 필드 추가
    });

    _tagController.clear();
  }

  Future<void> _deleteTag(String tagId) async {
    await FirebaseFirestore.instance.collection('tags').doc(tagId).delete();
  }

  // 특별 팀 여부를 토글하는 함수
  Future<void> _toggleSpecialTeam(String tagId, bool value) async {
    await FirebaseFirestore.instance.collection('tags').doc(tagId).update({
      'isSpecialTeam': value,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('태그 관리'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _tagController,
                      decoration: const InputDecoration(
                        labelText: '태그 이름',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _addTag,
                    child: const Text('추가'),
                  ),
                ],
              ),
            ),
            const ListTile(
              title: Text('태그 이름'),
              trailing: Text('특별팀 지정'),
            ),
            const Divider(height: 1),
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream:
                    FirebaseFirestore.instance.collection('tags').snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return const Center(
                        child: Text('태그를 불러오는 중 오류가 발생했습니다.'));
                  }

                  final docs = snapshot.data?.docs ?? [];
                  if (docs.isEmpty) {
                    return const Center(child: Text('등록된 태그가 없습니다.'));
                  }

                  return ListView.separated(
                    itemCount: docs.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final doc = docs[index];
                      final data = doc.data();
                      final tagName = data['name'] as String? ?? '';
                      final isSpecialTeam =
                          data['isSpecialTeam'] as bool? ?? false;

                      return ListTile(
                        title: Text(tagName),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Switch(
                              value: isSpecialTeam,
                              onChanged: (value) =>
                                  _toggleSpecialTeam(doc.id, value),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete,
                                  color: Colors.redAccent),
                              onPressed: () => _deleteTag(doc.id),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
