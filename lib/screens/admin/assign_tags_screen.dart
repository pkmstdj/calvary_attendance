import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AssignTagsScreen extends StatefulWidget {
  final String userId;

  const AssignTagsScreen({super.key, required this.userId});

  @override
  State<AssignTagsScreen> createState() => _AssignTagsScreenState();
}

class _AssignTagsScreenState extends State<AssignTagsScreen> {
  List<String> _userTags = [];

  @override
  void initState() {
    super.initState();
    _getUserTags();
  }

  Future<void> _getUserTags() async {
    final userDoc = await FirebaseFirestore.instance.collection('users').doc(widget.userId).get();
    if (userDoc.exists) {
      setState(() {
        _userTags = List<String>.from(userDoc.data()!['tags'] ?? []);
      });
    }
  }

  Future<void> _toggleTag(String tag, bool isSelected) async {
    final userRef = FirebaseFirestore.instance.collection('users').doc(widget.userId);

    if (isSelected) {
      await userRef.update({
        'tags': FieldValue.arrayUnion([tag])
      });
    } else {
      await userRef.update({
        'tags': FieldValue.arrayRemove([tag])
      });
    }
    _getUserTags();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('태그 할당'),
      ),
      body: SafeArea(
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance.collection('tags').snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return const Center(child: Text('태그를 불러오는 중 오류가 발생했습니다.'));
            }

            final docs = snapshot.data?.docs ?? [];
            if (docs.isEmpty) {
              return const Center(child: Text('등록된 태그가 없습니다.'));
            }

            return ListView.builder(
              itemCount: docs.length,
              itemBuilder: (context, index) {
                final doc = docs[index];
                final tagName = doc.data()['name'] as String? ?? '';
                final isSelected = _userTags.contains(tagName);

                return CheckboxListTile(
                  title: Text(tagName),
                  value: isSelected,
                  onChanged: (bool? value) {
                    if (value != null) {
                      _toggleTag(tagName, value);
                    }
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
