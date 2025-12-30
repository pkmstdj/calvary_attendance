import 'dart:async';
import 'package:calvary_attendance/screens/user/main_root_screen.dart';
import 'package:calvary_attendance/screens/user/phone_check_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LoadingScreen extends StatefulWidget {
  const LoadingScreen({super.key});

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen> {
  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    // 최소 1.5초 동안 로딩 화면을 보여주어 깜빡임을 방지합니다.
    await Future.delayed(const Duration(milliseconds: 1500));

    if (!mounted) return;

    final prefs = await SharedPreferences.getInstance();
    final savedPhoneNumber = prefs.getString('savedPhoneNumber');

    if (savedPhoneNumber != null && savedPhoneNumber.isNotEmpty) {
      // 수정: doc(phoneNumber).get() -> where('phoneNumber', ...).get()
      final querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('phoneNumber', isEqualTo: savedPhoneNumber)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        // 계정이 존재하면 메인 화면으로 이동
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => const MainRootScreen(),
            settings: RouteSettings(arguments: savedPhoneNumber),
          ),
        );
      } else {
        // 계정이 없으면 (등록 미완료), 전화번호 확인 화면으로 이동
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const PhoneCheckScreen()),
        );
      }
    } else {
      // 저장된 전화번호가 없으면 전화번호 확인 화면으로 이동
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const PhoneCheckScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.church, size: 80, color: Colors.grey),
            SizedBox(height: 24),
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('설정을 불러오는 중입니다...'),
          ],
        ),
      ),
    );
  }
}
