import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // SystemNavigator.pop()을 위해 임포트
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../utils/age_utils.dart';
import '../../utils/department_utils.dart';

enum CheckInStatus {
  success,
  alreadyCheckedIn,
  notApproved,
  notRegistered,
  error
}

class CheckInResult {
  final CheckInStatus status;
  final String message;

  CheckInResult(this.status, this.message);
}

class NfcCheckInScreen extends StatefulWidget {
  const NfcCheckInScreen({super.key});

  @override
  State<NfcCheckInScreen> createState() => _NfcCheckInScreenState();
}

class _NfcCheckInScreenState extends State<NfcCheckInScreen> {
  late final Future<CheckInResult> _checkInFuture;

  @override
  void initState() {
    super.initState();
    _checkInFuture = _processAttendance();
  }

  Future<CheckInResult> _processAttendance() async {
    try {
      debugPrint("[NfcCheckIn] 출석 체크 프로세스 시작");

      final prefs = await SharedPreferences.getInstance();
      final userPhone = prefs.getString('savedPhoneNumber');

      if (userPhone == null || userPhone.isEmpty) {
        debugPrint("[NfcCheckIn] 오류: 저장된 전화번호를 찾을 수 없음");
        return CheckInResult(CheckInStatus.notRegistered, "출석체크를 위해 먼저 앱에서 전화번호를 등록해주세요.");
      }
      debugPrint("[NfcCheckIn] SharedPreferences에서 찾은 전화번호: $userPhone");

      final userDoc = await FirebaseFirestore.instance.collection('users').doc(userPhone).get();
      final userData = userDoc.data();

      if (!userDoc.exists || userData == null || userData['permissionLevel'] == null) {
        debugPrint("[NfcCheckIn] 미승인 사용자");
        return CheckInResult(CheckInStatus.notApproved, "아직 승인되지 않은 사용자입니다.\n관리자의 승인을 기다리거나, 회원가입을 완료해주세요.");
      }
      debugPrint("[NfcCheckIn] Firestore에서 가져온 사용자 데이터: $userData");

      final now = DateTime.now();
      final year = DateFormat('yyyy').format(now);
      final monthDay = DateFormat('MM-dd').format(now);
      final dateString = DateFormat('yyyy-MM-dd').format(now);

      final attendanceDocRef = FirebaseFirestore.instance
          .collection('attendance')
          .doc(year)
          .collection(monthDay)
          .doc(userPhone);

      final attendanceDoc = await attendanceDocRef.get();

      if (attendanceDoc.exists) {
        final timestamp = (attendanceDoc.data()?['timestamp'] as Timestamp?)?.toDate();
        final timeString = timestamp != null ? DateFormat('HH:mm').format(timestamp) : '';
        debugPrint("[NfcCheckIn] 이미 출석 처리된 사용자 ($timeString)");
        return CheckInResult(CheckInStatus.alreadyCheckedIn, "${userData['name'] ?? '이름 없음'}님은 오늘 $timeString에\n이미 출석체크 되었습니다.");
      }

      final classYear = AgeCalculator.calculateClassYear(userData['birthDate']);
      final calculatedDepartment = DepartmentCalculator.calculateDepartment(userData['birthDate']);
      
      final finalDepartment = calculatedDepartment.isNotEmpty ? calculatedDepartment : (userData['department'] ?? '');

      debugPrint("[NfcCheckIn] 첫 출석으로 확인되어 출석 정보 기록 시작");
      await attendanceDocRef.set({
        'date': dateString,
        'timestamp': Timestamp.fromDate(now),
        'userName': userData['name'] ?? '이름 없음',
        'userPhone': userPhone,
        'department': finalDepartment,
        'classYear': classYear,
      });

      final timeString = DateFormat('yyyy-MM-dd HH:mm:ss').format(now);
      debugPrint("[NfcCheckIn] 출석 완료!");
      return CheckInResult(CheckInStatus.success, "✅ 출석이 완료되었습니다!\n${userData['name'] ?? '이름 없음'} 님, 환영합니다!\n\n$timeString");

    } catch (e) {
      debugPrint("[NfcCheckIn] 프로세스 중 예외 발생: $e");
      return CheckInResult(CheckInStatus.error, "출석 처리 중 오류가 발생했습니다: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('NFC 출석 체크'),
        automaticallyImplyLeading: false,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: FutureBuilder<CheckInResult>(
            future: _checkInFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 20),
                    Text('출석 정보를 확인 중입니다...', style: TextStyle(fontSize: 16)),
                  ],
                );
              }

              if (snapshot.hasData) {
                final result = snapshot.data!;
                IconData icon;
                Color iconColor;
                switch (result.status) {
                  case CheckInStatus.success:
                    icon = Icons.check_circle_outline_rounded;
                    iconColor = Colors.green;
                    break;
                  case CheckInStatus.alreadyCheckedIn:
                    icon = Icons.info_outline_rounded;
                    iconColor = Colors.orange;
                    break;
                  default:
                    icon = Icons.highlight_off_rounded;
                    iconColor = Colors.red;
                }
                return Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, color: iconColor, size: 80),
                    const SizedBox(height: 24),
                    Text(
                      result.message,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 18, height: 1.5),
                    ),
                    const SizedBox(height: 40),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).colorScheme.primary,
                          foregroundColor: Theme.of(context).colorScheme.onPrimary,
                        ),
                        child: const Text('확인'),
                        onPressed: () {
                          if (Navigator.of(context).canPop()) {
                            Navigator.of(context).pop();
                          } else {
                            SystemNavigator.pop();
                          }
                        },
                      ),
                    ),
                  ],
                );
              }

              return Text(snapshot.error?.toString() ?? "알 수 없는 오류가 발생했습니다.");
            },
          ),
        ),
      ),
    );
  }
}
