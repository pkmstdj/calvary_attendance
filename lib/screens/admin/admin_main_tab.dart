import 'package:flutter/material.dart';

import '../../utils/phone_utils.dart';
import '../common/news_card.dart';
import 'admin_approval_screen.dart';

class AdminMainTab extends StatefulWidget {
  final String phoneNumber; // 현재 관리자 전화번호
  final int permissionLevel; // 현재 관리자 권한 레벨

  const AdminMainTab({
    super.key,
    required this.phoneNumber,
    required this.permissionLevel,
  });

  @override
  State<AdminMainTab> createState() => _AdminMainTabState();
}

class _AdminMainTabState extends State<AdminMainTab> {
  // 승인 대기 목록 화면 열기
  void _openApprovalScreen() {
    Navigator.pushNamed(context, '/adminApprovalList');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('관리자 메인'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // QR 출석 체크 카드
                // Card(
                //   child: Padding(
                //     padding: const EdgeInsets.all(16),
                //     child: Column(
                //       crossAxisAlignment: CrossAxisAlignment.start,
                //       children: [
                //         Text(
                //           '관리자: ${formatPhoneNumber(widget.phoneNumber)}',
                //           style: const TextStyle(
                //             fontWeight: FontWeight.bold,
                //           ),
                //         ),
                //         const SizedBox(height: 4),
                //         Text(
                //           '권한 레벨: ${widget.permissionLevel}',
                //           style: const TextStyle(fontSize: 12),
                //         ),
                //         const SizedBox(height: 12),
                //         SizedBox(
                //           width: double.infinity,
                //           height: 40,
                //           child: ElevatedButton.icon(
                //             onPressed: () {
                //               ScaffoldMessenger.of(context).showSnackBar(
                //                 const SnackBar(
                //                   content: Text('QR 출석체크는 아직 준비중입니다.'),
                //                 ),
                //               );
                //             },
                //             icon: const Icon(Icons.qr_code),
                //             label: const Text('QR 출석 체크 (준비중)'),
                //           ),
                //         ),
                //       ],
                //     ),
                //   ),
                // ),
                // const SizedBox(height: 16),
                // 주보 카드
                NewsCard(phoneNumber: widget.phoneNumber),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
