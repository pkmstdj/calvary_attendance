import 'package:calvary_attendance/screens/admin/admin_approval_screen.dart';
import 'package:calvary_attendance/screens/admin/admin_root_screen.dart';
import 'package:calvary_attendance/screens/admin/tag_management_screen.dart';
import 'package:calvary_attendance/screens/user/create_user_screen.dart';
import 'package:calvary_attendance/screens/user/edit_profile_screen.dart';
import 'package:calvary_attendance/screens/user/main_root_screen.dart';
import 'package:calvary_attendance/screens/user/phone_check_screen.dart';
import 'package:calvary_attendance/screens/loading_screen.dart';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Firestore 사용

import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '갈보리교회 출석체크',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF003A70)),
        useMaterial3: true,
      ),
      // 앱의 첫 화면으로 버전 체크 화면을 설정
      home: const VersionCheckScreen(),
      routes: {
        // 실제 존재하는 경로만 남김
        '/phoneCheck': (context) => const PhoneCheckScreen(),
        '/createUser': (context) => const CreateUserScreen(),
        '/editProfile': (context) => const EditProfileScreen(),
        '/mainRoot': (context) => const MainRootScreen(),
        '/loading': (context) => const LoadingScreen(),

        // Admin routes
        '/adminRoot': (context) => const AdminRootScreen(),
        '/adminApproval': (context) => const AdminApprovalScreen(),
        '/adminTag': (context) => const TagManagementScreen(),
      },
    );
  }
}

// 앱 시작 시 버전 체크를 먼저 수행하는 화면
class VersionCheckScreen extends StatefulWidget {
  const VersionCheckScreen({super.key});

  @override
  State<VersionCheckScreen> createState() => _VersionCheckScreenState();
}

class _VersionCheckScreenState extends State<VersionCheckScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkVersion());
  }

  Future<void> _checkVersion() async {
    // 사용자가 직접 수정할 수 있는 현재 앱 버전
    const String currentAppVersion = '0.0.2';

    try {
      // Firestore에서 원격 버전 가져오기
      final docRef = FirebaseFirestore.instance.collection('check').doc('app');
      final docSnap = await docRef.get();

      if (!mounted) return;

      String? remoteVersion;
      if (docSnap.exists && docSnap.data() != null) {
        remoteVersion = docSnap.data()!['version'] as String?;
      }

      if (remoteVersion == null) {
        // 원격 버전을 가져오지 못하면, 기존 로딩 화면으로 이동
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const LoadingScreen()),
        );
        return;
      }

      if (currentAppVersion == remoteVersion) {
        // 버전이 일치하면, 기존 로딩 화면으로 이동
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const LoadingScreen()),
        );
      } else {
        // 버전이 다르면 업데이트 팝업 표시
        _showUpdateDialog();
      }
    } catch (e) {
      // 오류 발생 시에도 일단 로딩 화면으로 이동 (오프라인 등)
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const LoadingScreen()),
        );
      }
    }
  }

  void _showUpdateDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('업데이트 필요'),
          content: const Text('버전이 맞지 않습니다. 업데이트가 필요합니다.'),
          actions: <Widget>[
            TextButton(
              child: const Text('확인'),
              onPressed: () {
                SystemNavigator.pop(); // 앱 종료
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}
