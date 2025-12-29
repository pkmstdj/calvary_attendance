import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:elegant_notification/elegant_notification.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PhoneCheckScreen extends StatefulWidget {
  const PhoneCheckScreen({super.key});

  @override
  State<PhoneCheckScreen> createState() => _PhoneCheckScreenState();
}

class _PhoneCheckScreenState extends State<PhoneCheckScreen> {
  final TextEditingController _phoneController = TextEditingController();
  bool _isLoading = false;
  bool _triedAuto = false;
  bool _isFormatting = false;

  @override
  void initState() {
    super.initState();
    _phoneController.addListener(_formatPhoneNumber);
    _tryAutoLogin();
  }

  void _formatPhoneNumber() {
    if (_isFormatting) return;

    _isFormatting = true;
    final text = _phoneController.text.replaceAll(RegExp(r'[^0-9]'), '');
    var formatted = '';

    if (text.length > 3) {
      formatted += text.substring(0, 3);
      if (text.length > 7) {
        formatted += '-${text.substring(3, 7)}';
        if (text.length > 11) {
          formatted += '-${text.substring(7, 11)}';
        } else {
          formatted += '-${text.substring(7)}';
        }
      } else {
        formatted += '-${text.substring(3)}';
      }
    } else {
      formatted = text;
    }

    _phoneController.value = _phoneController.value.copyWith(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
    _isFormatting = false;
  }

  Future<void> _tryAutoLogin() async {
    setState(() {
      _isLoading = true;
    });
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('savedPhoneNumber');
    if (saved != null && saved.isNotEmpty) {
      await _checkUserAndNavigate(saved, remember: false);
    }
    if (mounted) {
      setState(() {
        _isLoading = false;
        _triedAuto = true;
      });
    }
  }

  Future<void> _checkUserAndNavigate(
    String phoneNumber, {
    bool remember = true,
  }) async {
    final normalized = phoneNumber.replaceAll(RegExp(r'[^0-9]'), '');
    if (normalized.isEmpty) {
      ElegantNotification.error(
        title: const Text('오류'),
        description: const Text('전화번호를 입력해 주세요.'),
      ).show(context);
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(normalized)
          .get();

      if (remember) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('savedPhoneNumber', normalized);
      }

      if (!mounted) return;

      if (doc.exists) {
        Navigator.pushReplacementNamed(
          context,
          '/root',
          arguments: normalized,
        );
      } else {
        Navigator.pushReplacementNamed(
          context,
          '/createUser',
          arguments: normalized,
        );
      }
    } catch (e) {
      if (!mounted) return;
      ElegantNotification.error(
        title: const Text('오류'),
        description: Text('오류가 발생했습니다: $e'),
      ).show(context);
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _onSubmit() {
    _checkUserAndNavigate(_phoneController.text);
  }

  @override
  void dispose() {
    _phoneController.removeListener(_formatPhoneNumber);
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_triedAuto || _isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('전화번호 확인'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                '처음 한 번만 전화번호를 입력하면\n다음부터는 자동으로 접속됩니다.',
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: '전화번호',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _onSubmit,
                  child: const Text(
                    '확인',
                    style: TextStyle(
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
    );
  }
}
