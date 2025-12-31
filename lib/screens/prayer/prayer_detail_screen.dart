import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class PrayerDetailScreenArguments {
  final String userDocId;
  final String prayerDocId;
  final String text;
  final String? date;
  final bool isOwner;

  PrayerDetailScreenArguments({
    required this.userDocId,
    required this.prayerDocId,
    required this.text,
    this.date,
    required this.isOwner,
  });
}

class PrayerDetailScreen extends StatelessWidget {
  const PrayerDetailScreen({super.key});

  Future<void> _deletePrayer(BuildContext context, String userDocId, String prayerDocId) async {
    bool confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('기도제목 삭제'),
        content: const Text('정말로 이 기도제목을 삭제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('삭제'),
          ),
        ],
      ),
    ) ?? false;

    if (confirm) {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userDocId)
            .collection('prayerRequests')
            .doc(prayerDocId)
            .delete();
        if (context.mounted) Navigator.pop(context);
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('기도제목 삭제 중 오류가 발생했습니다.')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)!.settings.arguments as PrayerDetailScreenArguments;

    return Scaffold(
      appBar: AppBar(
        title: const Text('기도제목 상세보기'),
        actions: [
          if (args.isOwner)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: '삭제',
              onPressed: () => _deletePrayer(context, args.userDocId, args.prayerDocId),
            ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (args.date != null)
                  Text(
                    args.date!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey),
                  ),
                if (args.date != null) const SizedBox(height: 16),
                Text(
                  args.text,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
