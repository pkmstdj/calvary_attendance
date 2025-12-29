import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:panara_dialogs/panara_dialogs.dart';

class AdminAttendanceTab extends StatefulWidget {
  const AdminAttendanceTab({super.key});

  @override
  State<AdminAttendanceTab> createState() => _AdminAttendanceTabState();
}

class _AdminAttendanceTabState extends State<AdminAttendanceTab> {
  String get _todayDateString {
    final now = DateTime.now();
    return DateFormat('yyyy-MM-dd').format(now);
  }

  String _bytesToHexString(List<int> bytes) {
    return bytes.map((e) => e.toRadixString(16).padLeft(2, '0')).join(':');
  }

  Future<void> _startNfcAttendanceScan() async {
    if (!await NfcManager.instance.isAvailable()) {
      _showErrorDialog("NFC를 사용할 수 없는 기기입니다.");
      return;
    }

    PanaraInfoDialog.show(
      context,
      title: "NFC 출석 체크",
      message: "NFC 스티커를 휴대폰 뒷면에 태그해주세요.",
      buttonText: "취소",
      onTapDismiss: () {
        NfcManager.instance.stopSession();
        Navigator.pop(context);
      },
      panaraDialogType: PanaraDialogType.normal,
      barrierDismissible: false,
    );

    NfcManager.instance.startSession(
      pollingOptions: {
        NfcPollingOption.iso14443,
        NfcPollingOption.iso15693,
        NfcPollingOption.iso18092,
      },
      onDiscovered: (NfcTag tag) async {
        await NfcManager.instance.stopSession();
        Navigator.pop(context); // Close the scanning dialog

        final ndef = (tag.data as Map<String, dynamic>)['ndef'];
        if (ndef == null || ndef is! Map) {
          _showErrorDialog("태그 ID를 읽을 수 없습니다. NDEF 형식이 아닌 태그일 수 있습니다.");
          return;
        }
        
        final identifier = ndef['identifier'] as List<int>?;

        if (identifier == null) {
          _showErrorDialog("태그 ID 식별자를 찾을 수 없습니다.");
          return;
        }
        final String tagId = _bytesToHexString(identifier);

        // Find user by NFC tag
        final userQuery = await FirebaseFirestore.instance
            .collection('users')
            .where('nfcTagId', isEqualTo: tagId)
            .limit(1)
            .get();

        if (userQuery.docs.isEmpty) {
          _showErrorDialog("등록되지 않은 NFC 태그입니다.");
          return;
        }

        final userDoc = userQuery.docs.first;
        final userData = userDoc.data() as Map<String, dynamic>?;
        if (userData == null) {
          _showErrorDialog("사용자 데이터를 찾을 수 없습니다.");
          return;
        }
        final userName = userData['name'] ?? '알 수 없는 사용자';
        final userPhone = userDoc.id;

        // Check if already attended today
        final attendanceRecordId = '$_todayDateString-$userPhone';
        final attendanceDoc = await FirebaseFirestore.instance
            .collection('attendance')
            .doc(attendanceRecordId)
            .get();

        if (attendanceDoc.exists) {
          PanaraInfoDialog.show(context,
              title: "출석 확인",
              message: "$userName 님은 이미 출석체크 되었습니다.",
              buttonText: "확인",
              onTapDismiss: () => Navigator.pop(context),
              panaraDialogType: PanaraDialogType.warning);
          return;
        }

        // Record attendance
        try {
          await FirebaseFirestore.instance
              .collection('attendance')
              .doc(attendanceRecordId)
              .set({
            'userName': userName,
            'userPhone': userPhone,
            'timestamp': FieldValue.serverTimestamp(),
            'date': _todayDateString,
          });

          PanaraInfoDialog.show(context,
              title: "출석 완료",
              message: "$userName 님의 출석이 완료되었습니다!",
              buttonText: "확인",
              onTapDismiss: () => Navigator.pop(context),
              panaraDialogType: PanaraDialogType.success);
        } catch (e) {
          _showErrorDialog("출석 기록 중 오류가 발생했습니다: $e");
        }
      },
    );
  }

  void _showErrorDialog(String message) {
    if (!mounted) return;
    PanaraInfoDialog.show(
      context,
      title: "오류",
      message: message,
      buttonText: "확인",
      onTapDismiss: () => Navigator.pop(context),
      panaraDialogType: PanaraDialogType.error,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('출석 체크 ($_todayDateString)'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _startNfcAttendanceScan,
                  icon: const Icon(Icons.nfc),
                  label: const Text('NFC로 출석체크', style: TextStyle(fontSize: 18)),
                ),
              ),
            ),
            const Divider(),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('오늘 출석 현황', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('attendance')
                    .where('date', isEqualTo: _todayDateString)
                    .orderBy('timestamp', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return const Center(child: Text('출석 정보를 불러오는 중 오류가 발생했습니다.'));
                  }
                  final docs = snapshot.data?.docs ?? [];

                  if (docs.isEmpty) {
                    return const Center(child: Text('오늘 출석한 청년이 없습니다.'));
                  }
                  
                  return ListView.builder(
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final data = docs[index].data() as Map<String, dynamic>;
                      final name = data['userName'] ?? '이름 없음';
                      final timestamp = data['timestamp'] as Timestamp?;
                      final timeString = timestamp != null
                          ? DateFormat('HH:mm:ss').format(timestamp.toDate())
                          : '';

                      return ListTile(
                        leading: CircleAvatar(child: Text('${index + 1}')),
                        title: Text(name),
                        trailing: Text(timeString),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
