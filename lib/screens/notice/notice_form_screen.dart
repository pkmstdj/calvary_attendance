import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:elegant_notification/elegant_notification.dart';
import 'package:flutter/material.dart';

import 'notice_detail_screen.dart';

class NoticeFormScreen extends StatefulWidget {
  const NoticeFormScreen({super.key});

  @override
  State<NoticeFormScreen> createState() => _NoticeFormScreenState();
}

class _NoticeFormScreenState extends State<NoticeFormScreen> {
  late NoticeFormArguments _args;
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();
  bool _isAdminNotice = false;
  bool _initialized = false;
  bool _isSubmitting = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      final args = ModalRoute.of(context)!.settings.arguments;
      if (args is NoticeFormArguments) {
        _args = args;
        _titleController.text = args.initialTitle ?? '';
        _contentController.text = args.initialContent ?? '';
        _isAdminNotice = args.isAdminNoticeDefault;
        _initialized = true;
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();

    if (title.isEmpty || content.isEmpty) {
      ElegantNotification.error(
        title: const Text('오류'),
        description: const Text('제목과 내용을 모두 입력해 주세요.'),
      ).show(context);
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final collection = FirebaseFirestore.instance.collection('notices');

      if (_args.isEdit && _args.noticeId != null) {
        await collection.doc(_args.noticeId).update({
          'title': title,
          'content': content,
          'updatedAt': FieldValue.serverTimestamp(),
          'hasEdited': true,
          'isAdminNotice': _isAdminNotice,
        });
      } else {
        final now = FieldValue.serverTimestamp();
        await collection.add({
          'title': title,
          'content': content,
          'createdAt': now,
          'updatedAt': now,
          'hasEdited': false,
          'authorPhoneNumber': _args.phoneNumber,
          'authorPermissionLevel': _args.viewerPermissionLevel,
          'isAdminNotice': _isAdminNotice,
        });
      }

      if (!mounted) return;
      ElegantNotification.success(
        title: const Text('성공'),
        description: const Text('저장되었습니다.'),
      ).show(context);
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ElegantNotification.error(
        title: const Text('오류'),
        description: Text('저장 중 오류가 발생했습니다: $e'),
      ).show(context);
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final isEdit = _args.isEdit;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? '공지사항 수정' : '공지사항 작성'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: '제목',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _contentController,
                  maxLines: 8,
                  decoration: const InputDecoration(
                    labelText: '내용',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Text('관리자 공지'),
                    const SizedBox(width: 8),
                    Switch(
                      value: _isAdminNotice,
                      onChanged: (value) {
                        setState(() {
                          _isAdminNotice = value;
                        });
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 48,
                  child: _isSubmitting
                      ? const Center(child: CircularProgressIndicator())
                      : ElevatedButton(
                          onPressed: _save,
                          child: Text(
                            isEdit ? '수정 완료' : '작성 완료',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
