import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'create_user_screen.dart';
import 'main_root_screen.dart';

class PhoneCheckScreen extends StatefulWidget {
  const PhoneCheckScreen({super.key});

  @override
  State<PhoneCheckScreen> createState() => _PhoneCheckScreenState();
}

class _PhoneCheckScreenState extends State<PhoneCheckScreen> {
  final _phoneController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _isTermsAgreed = false; // 약관 동의 여부

  Future<void> _checkPhoneNumber() async {
    if (!_isTermsAgreed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('약관에 동의해야 서비스를 이용할 수 있습니다.')),
      );
      return;
    }

    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final phoneNumber = '010${_phoneController.text}';

    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('phoneNumber', isEqualTo: phoneNumber)
          .limit(1)
          .get();

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('savedPhoneNumber', phoneNumber);

      if (!mounted) return;

      if (querySnapshot.docs.isNotEmpty) {
        // 사용자가 존재하면 메인 화면으로 이동
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => const MainRootScreen(),
            settings: RouteSettings(arguments: phoneNumber),
          ),
        );
      } else {
        // 사용자가 없으면 정보 등록 화면으로 이동
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => const CreateUserScreen(),
          ),
        );
      }
    } catch (e) {
      // 오류 처리
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('오류가 발생했습니다: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // 약관 보여주기
  void _showTermsDialog() {
    showDialog(
      context: context,
      barrierDismissible: false, // 바깥 터치로 닫기 방지
      builder: (context) => const TermsDialog(),
    ).then((result) {
      if (result == true) {
        setState(() {
          _isTermsAgreed = true;
        });
      } else {
        setState(() {
          _isTermsAgreed = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Spacer(),
                const Text(
                  '반갑습니다!',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Text(
                  '서비스를 이용하시려면 전화번호를 입력해주세요.',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 30),
                
                // 약관 동의 버튼
                InkWell(
                  onTap: _showTermsDialog,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _isTermsAgreed ? Icons.check_circle : Icons.error_outline,
                        color: _isTermsAgreed ? Colors.green : Colors.red,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '개인정보이용동의(필수)',
                        style: TextStyle(
                          color: _isTermsAgreed ? Colors.green : Colors.red,
                          fontWeight: FontWeight.bold,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // 전화번호 입력 (동의 전에는 비활성화)
                AbsorbPointer(
                  absorbing: !_isTermsAgreed,
                  child: Opacity(
                    opacity: _isTermsAgreed ? 1.0 : 0.5,
                    child: Row(
                      children: [
                        const Text('010', style: TextStyle(fontSize: 18)),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            controller: _phoneController,
                            keyboardType: TextInputType.number,
                            maxLength: 8,
                            enabled: _isTermsAgreed, // 실제 입력 비활성화
                            decoration: const InputDecoration(
                              labelText: '전화번호 8자리',
                              counterText: '',
                              border: OutlineInputBorder(),
                            ),
                            validator: (value) {
                              if (value == null ||
                                  value.isEmpty ||
                                  value.length != 8) {
                                return '8자리를 정확히 입력해주세요.';
                              }
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  height: 50,
                  child: ElevatedButton(
                    onPressed: (_isLoading || !_isTermsAgreed) ? null : _checkPhoneNumber,
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text('확인'),
                  ),
                ),
                const Spacer(flex: 2),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class TermsDialog extends StatefulWidget {
  const TermsDialog({super.key});

  @override
  State<TermsDialog> createState() => _TermsDialogState();
}

class _TermsDialogState extends State<TermsDialog> {
  final ScrollController _scrollController = ScrollController();
  bool _isScrolledToBottom = false;
  String? _termsContent;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchTerms();
    _scrollController.addListener(_scrollListener);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchTerms() async {
    try {
      final doc = await FirebaseFirestore.instance.collection('check').doc('terms').get();
      if (doc.exists && doc.data() != null) {
        setState(() {
          _termsContent = doc.data()!['contents'] as String?;
          _isLoading = false;
        });
      } else {
        setState(() {
          _termsContent = '약관 내용을 불러올 수 없습니다.';
          _isLoading = false;
        });
      }
      
      // 내용이 짧아서 스크롤이 필요 없는 경우 바로 활성화 (렌더링 후 체크)
      WidgetsBinding.instance.addPostFrameCallback((_) {
         _checkIfScrollable();
      });

    } catch (e) {
      setState(() {
        _termsContent = '오류 발생: $e';
        _isLoading = false;
      });
    }
  }

  void _scrollListener() {
    if (!_isScrolledToBottom &&
        _scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 10) { // 약간의 여유
      setState(() {
        _isScrolledToBottom = true;
      });
    }
  }

  void _checkIfScrollable() {
     if (_scrollController.hasClients && 
        _scrollController.position.maxScrollExtent <= 0) {
       setState(() {
         _isScrolledToBottom = true;
       });
     }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('개인정보 이용약관'),
      content: SizedBox(
        width: double.maxFinite,
        height: 400, // 고정 높이
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(8.0),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: SingleChildScrollView(
                        controller: _scrollController,
                        child: Text(_termsContent ?? ''),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (!_isScrolledToBottom)
                    const Text(
                      '스크롤을 끝까지 내려주세요.',
                      style: TextStyle(color: Colors.red, fontSize: 12),
                    ),
                ],
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false), // 취소
          child: const Text('취소', style: TextStyle(color: Colors.grey)),
        ),
        ElevatedButton(
          onPressed: _isScrolledToBottom
              ? () => Navigator.of(context).pop(true) // 동의
              : null, // 비활성화
          child: const Text('동의합니다'),
        ),
      ],
    );
  }
}
