import 'package:flutter/material.dart';

class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  void _onAgree(BuildContext context) {
    Navigator.pushReplacementNamed(context, '/phoneCheck');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('약관 동의'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 8),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '갈보리 출석 & 기도제목 앱 약관',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.brown.shade200),
                  ),
                  child: const Padding(
                    padding: EdgeInsets.all(12),
                    child: SingleChildScrollView(
                      child: Text(
                        '여기에 약관 내용을 작성하세요.\n\n'
                        '스크롤 가능한 영역입니다.\n\n'
                        '※ 실제 배포 시 교회 내 개인정보 처리 및 사용 동의 문구를 넣어 주세요.',
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () => _onAgree(context),
                  child: const Text(
                    '동의하고 시작하기',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
