import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
  final _smsController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  
  bool _isLoading = false;
  bool _isTermsAgreed = false; // 약관 동의 여부
  bool _codeSent = false; // 인증번호 발송 여부
  String? _verificationId; // Firebase 인증 ID

  // 1. 전화번호 인증 시작
  Future<void> _verifyPhoneNumber() async {
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

    // 수정: 입력된 8자리에 +82 10을 붙여 E.164 포맷 완성
    final phoneNumber = '+8210${_phoneController.text}'; 

    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        verificationCompleted: (PhoneAuthCredential credential) async {
          // 안드로이드에서 자동 인증이 완료된 경우
          await FirebaseAuth.instance.signInWithCredential(credential);
          _onAuthSuccess();
        },
        verificationFailed: (FirebaseAuthException e) {
          setState(() {
            _isLoading = false;
          });
          String message = '인증 실패: ${e.message}';
          if (e.code == 'invalid-phone-number') {
            message = '유효하지 않은 전화번호입니다.';
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(message)),
          );
        },
        codeSent: (String verificationId, int? resendToken) {
          setState(() {
            _verificationId = verificationId;
            _codeSent = true;
            _isLoading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('인증번호가 발송되었습니다.')),
          );
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          _verificationId = verificationId;
        },
      );
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('오류가 발생했습니다: $e')),
      );
    }
  }

  // 2. 인증번호 확인 및 로그인
  Future<void> _signInWithSmsCode() async {
    if (_smsController.text.isEmpty || _verificationId == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: _smsController.text,
      );

      await FirebaseAuth.instance.signInWithCredential(credential);
      _onAuthSuccess();
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('인증번호가 올바르지 않거나 오류가 발생했습니다.')),
      );
    }
  }

  // 3. 인증 성공 후 처리 (기존 로직 유지 + UID 저장 가능성 열어둠)
  Future<void> _onAuthSuccess() async {
    final rawPhoneNumber = '010${_phoneController.text}'; // 기존 포맷 유지
    final user = FirebaseAuth.instance.currentUser;

    try {
      // 1. 기존 방식대로 전화번호로 사용자 검색 (마이그레이션 고려)
      // 또는 user.uid로 검색하도록 변경할 수도 있음
      final querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('phoneNumber', isEqualTo: rawPhoneNumber)
          .limit(1)
          .get();

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('savedPhoneNumber', rawPhoneNumber);

      if (!mounted) return;

      if (querySnapshot.docs.isNotEmpty) {
        // 이미 사용자가 존재하면
        // 필요하다면 여기서 user.uid를 해당 문서에 업데이트 해줄 수도 있음
        
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => const MainRootScreen(),
            settings: RouteSettings(arguments: rawPhoneNumber),
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
       if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('사용자 확인 중 오류: $e')),
        );
      }
    }
  }

  // 약관 보여주기
  void _showTermsDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
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
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 40), // Spacer 대신 고정 여백 또는 유연한 공간 사용
                        const Text(
                          '반갑습니다!',
                          style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          '서비스를 이용하시려면 전화번호 인증이 필요합니다.',
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
                          absorbing: !_isTermsAgreed || _codeSent, // 코드가 전송되면 수정 불가
                          child: Opacity(
                            opacity: (_isTermsAgreed && !_codeSent) ? 1.0 : 0.5,
                            child: Row(
                              children: [
                                const Text('010', style: TextStyle(fontSize: 18)),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: TextFormField(
                                    controller: _phoneController,
                                    keyboardType: TextInputType.number,
                                    maxLength: 8,
                                    enabled: _isTermsAgreed && !_codeSent,
                                    decoration: const InputDecoration(
                                      labelText: '전화번호 8자리',
                                      counterText: '',
                                      border: OutlineInputBorder(),
                                    ),
                                    validator: (value) {
                                      if (value == null || value.isEmpty || value.length != 8) {
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
                        
                        // 인증번호 입력 필드 (코드가 전송된 경우에만 표시)
                        if (_codeSent) ...[
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _smsController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: '인증번호 6자리',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ],

                        const SizedBox(height: 24),
                        
                        // 버튼 (인증 요청 or 확인)
                        SizedBox(
                          height: 50,
                          child: ElevatedButton(
                            onPressed: (_isLoading || !_isTermsAgreed) 
                                ? null 
                                : (_codeSent ? _signInWithSmsCode : _verifyPhoneNumber),
                            child: _isLoading
                                ? const CircularProgressIndicator(color: Colors.white)
                                : Text(_codeSent ? '인증 확인' : '인증번호 발송'),
                          ),
                        ),
                        const SizedBox(height: 40), // 하단 여백 확보
                      ],
                    ),
                  ),
                ),
              ),
            );
          }
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
        if (mounted) {
          setState(() {
            _termsContent = doc.data()!['contents'] as String?;
            _isLoading = false;
          });
        }
      } else {
         if (mounted) {
          setState(() {
            _termsContent = '약관 내용을 불러올 수 없습니다.';
            _isLoading = false;
          });
         }
      }
      
      // 내용이 짧아서 스크롤이 필요 없는 경우 바로 활성화 (렌더링 후 체크)
      WidgetsBinding.instance.addPostFrameCallback((_) {
         _checkIfScrollable();
      });

    } catch (e) {
       if (mounted) {
        setState(() {
          _termsContent = '오류 발생: $e';
          _isLoading = false;
        });
       }
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
