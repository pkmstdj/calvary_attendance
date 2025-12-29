import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:panara_dialogs/panara_dialogs.dart';

import '../../utils/date_utils.dart';
import '../../utils/phone_utils.dart';
import '../../utils/user_utils.dart';
import '../prayer/prayer_detail_screen.dart';

class AdminUserProfileArguments {
  final String targetPhoneNumber;
  final String viewerPhoneNumber;
  final int viewerPermissionLevel;

  AdminUserProfileArguments({
    required this.targetPhoneNumber,
    required this.viewerPhoneNumber,
    required this.viewerPermissionLevel,
  });
}

class AdminUserProfileScreen extends StatefulWidget {
  const AdminUserProfileScreen({super.key});

  @override
  State<AdminUserProfileScreen> createState() =>
      _AdminUserProfileScreenState();
}

class _AdminUserProfileScreenState extends State<AdminUserProfileScreen> {
  AdminUserProfileArguments? _args;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      final modalRoute = ModalRoute.of(context);
      if (modalRoute != null) {
        final routeArgs = modalRoute.settings.arguments;
        if (routeArgs is AdminUserProfileArguments) {
          _args = routeArgs;
        }
      }
      _initialized = true;
    }
  }

  void _openPrayerDetail(String prayerId) {
    if (_args == null) return;
    Navigator.pushNamed(
      context,
      '/prayerDetail',
      arguments: PrayerDetailArguments(
        prayerId: prayerId,
        viewerPhoneNumber: _args!.viewerPhoneNumber,
        viewerPermissionLevel: _args!.viewerPermissionLevel,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_args == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('오류')),
        body: const Center(child: Text('사용자 정보를 불러오지 못했습니다.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('청년 프로필'),
      ),
      body: SafeArea(
        child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance.collection('users').doc(_args!.targetPhoneNumber).snapshots(),
          builder: (context, userSnap) {
            if (!userSnap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final userData = userSnap.data?.data();
            if (userData == null) {
              return const Center(child: Text('사용자 정보를 찾을 수 없습니다.'));
            }

            final canEditProfile = _args!.viewerPermissionLevel <= 2;
            final targetPermissionLevel = userData['permissionLevel'] as int? ?? 3;
            final canChangePermission = _args!.viewerPermissionLevel < targetPermissionLevel;

            return Column(
              children: [
                _UserProfileSection(
                  userData: userData,
                  canEdit: canEditProfile,
                  canChangePermission: canChangePermission,
                  targetPhoneNumber: _args!.targetPhoneNumber,
                  viewerPermissionLevel: _args!.viewerPermissionLevel,
                ),
                const Divider(height: 1),
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text('기도제목 목록', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                ),
                Expanded(
                  child: _PrayerRequestList(
                    prayerStream: FirebaseFirestore.instance
                        .collection('prayerRequests')
                        .where('phoneNumber', isEqualTo: _args!.targetPhoneNumber)
                        .orderBy('createdAt', descending: true)
                        .snapshots(),
                    onPrayerTap: _openPrayerDetail,
                    // viewerPhoneNumber를 전달해야 내가 확인했는지 알 수 있습니다.
                    viewerPhoneNumber: _args!.viewerPhoneNumber,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// MARK: - User Profile Section Widget
class _UserProfileSection extends StatelessWidget {
  final Map<String, dynamic> userData;
  final bool canEdit;
  final bool canChangePermission;
  final String targetPhoneNumber;
  final int viewerPermissionLevel;

  const _UserProfileSection({
    required this.userData,
    required this.canEdit,
    required this.canChangePermission,
    required this.targetPhoneNumber,
    required this.viewerPermissionLevel,
  });

  Future<void> _showEditProfileDialog(BuildContext context) async {
    Navigator.pushNamed(context, '/editProfile', arguments: targetPhoneNumber);
  }

  Future<void> _showChangePermissionDialog(BuildContext context) async {
    Navigator.pushNamed(
      context,
      '/changePermission',
      arguments: {
        'targetPhoneNumber': targetPhoneNumber,
        'viewerPermissionLevel': viewerPermissionLevel,
        'currentPermissionLevel': userData['permissionLevel'] as int? ?? 3,
      },
    );
  }

  String _bytesToHexString(List<int> bytes) {
    return bytes.map((e) => e.toRadixString(16).padLeft(2, '0')).join(':');
  }

  Future<void> _showRegisterNfcDialog(BuildContext context, String name) async {
    if (!await NfcManager.instance.isAvailable()) {
      PanaraInfoDialog.show(context, title: "오류", message: "NFC를 사용할 수 없는 기기입니다.", buttonText: "확인", onTapDismiss: () => Navigator.pop(context), panaraDialogType: PanaraDialogType.error);
      return;
    }

    PanaraInfoDialog.show(
      context,
      title: "NFC 태그 스캔",
      message: "등록할 NFC 스티커를 휴대폰 뒷면에 태그해주세요.",
      buttonText: "취소",
      onTapDismiss: () {
        NfcManager.instance.stopSession();
        Navigator.pop(context);
      },
      panaraDialogType: PanaraDialogType.normal,
    );

    NfcManager.instance.startSession(
        pollingOptions: {
          NfcPollingOption.iso14443,
          NfcPollingOption.iso15693,
          NfcPollingOption.iso18092,
        },
        onDiscovered: (NfcTag tag) async {
          await NfcManager.instance.stopSession();
          Navigator.pop(context); // 스캔 다이얼로그 닫기

          final ndef = (tag.data as Map<String, dynamic>)['ndef'];
          if (ndef == null || ndef is! Map) {
            PanaraInfoDialog.show(context, title: "오류", message: "태그 ID를 읽을 수 없습니다. NDEF 형식이 아닌 태그일 수 있습니다.", buttonText: "확인", onTapDismiss: () => Navigator.pop(context), panaraDialogType: PanaraDialogType.error, barrierDismissible: false);
            return;
          }
          final identifier = ndef['identifier'] as List<int>?;

          if (identifier == null) {
            PanaraInfoDialog.show(context, title: "오류", message: "태그 ID 식별자를 찾을 수 없습니다.", buttonText: "확인", onTapDismiss: () => Navigator.pop(context), panaraDialogType: PanaraDialogType.error, barrierDismissible: false);
            return;
          }
          final String tagId = _bytesToHexString(identifier);

          // 이미 다른 사용자에게 등록된 태그인지 확인
          final existingUser = await FirebaseFirestore.instance.collection('users').where('nfcTagId', isEqualTo: tagId).limit(1).get();
          if (existingUser.docs.isNotEmpty) {
            final existingUserData = existingUser.docs.first.data() as Map<String, dynamic>?;
            if (existingUserData == null) {
                PanaraInfoDialog.show(context, title: "오류", message: "기존 사용자 정보를 읽을 수 없습니다.", buttonText: "확인", onTapDismiss: () => Navigator.pop(context), panaraDialogType: PanaraDialogType.error);
                return;
            }
            final existingUserName = existingUserData['name'] ?? '다른 사용자';
            PanaraInfoDialog.show(context, title: "오류", message: "이미 '$existingUserName'님에게 등록된 태그입니다.", buttonText: "확인", onTapDismiss: () => Navigator.pop(context), panaraDialogType: PanaraDialogType.error);
            return;
          }

          PanaraConfirmDialog.show(
            context,
            title: "태그 등록 확인",
            message: "이 NFC 태그를 $name 님의 태그로 등록하시겠습니까?",
            confirmButtonText: "등록",
            cancelButtonText: "취소",
            onTapConfirm: () async {
              try {
                await FirebaseFirestore.instance.collection('users').doc(targetPhoneNumber).update({'nfcTagId': tagId});
                Navigator.pop(context); // 확인 다이얼로그 닫기
                PanaraInfoDialog.show(context, title: "성공", message: "NFC 태그가 성공적으로 등록되었습니다.", buttonText: "확인", onTapDismiss: () => Navigator.pop(context), panaraDialogType: PanaraDialogType.success);
              } catch (e) {
                Navigator.pop(context); // 확인 다이얼로그 닫기
                PanaraInfoDialog.show(context, title: "오류", message: "태그 등록 중 오류가 발생했습니다: $e", buttonText: "확인", onTapDismiss: () => Navigator.pop(context), panaraDialogType: PanaraDialogType.error);
              }
            },
            onTapCancel: () => Navigator.pop(context),
            panaraDialogType: PanaraDialogType.normal,
          );
        });
  }

  @override
  Widget build(BuildContext context) {
    final name = userData['name'] ?? '이름 없음';
    final birthRaw = userData['birthDate'] ?? '';
    final leaderPhone = userData['smallGroupLeaderPhone'] ?? '';
    final permissionLevel = userData['permissionLevel'] as int? ?? 3;
    final nfcTagId = userData['nfcTagId'] as String?;

    String gisuText = '-';
    String youthGroupText = '-';
    if (birthRaw.length >= 4) {
      final birthYear = int.tryParse(birthRaw.substring(0, 4));
      if (birthYear != null) {
        gisuText = '${calculateGisu(birthYear)}기';
        youthGroupText = calculateYouthGroup(birthYear);
      }
    }

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      Chip(label: Text(getPermissionLabel(permissionLevel), style: const TextStyle(fontSize: 12))),
                    ],
                  ),
                  const Divider(height: 24),
                  _buildInfoRow('기수', gisuText),
                  _buildInfoRow('소속', youthGroupText),
                  _buildLeaderInfoRow(context, '소그룹', leaderPhone),
                  if (nfcTagId != null && nfcTagId.isNotEmpty)
                    _buildInfoRow('NFC ID', nfcTagId),
                ],
              ),
            ),
          ),
          if (canEdit)
            Padding(
              padding: const EdgeInsets.only(top: 12.0),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _showEditProfileDialog(context),
                  icon: const Icon(Icons.edit),
                  label: const Text('프로필 수정'),
                ),
              ),
            ),
          if (canChangePermission)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _showChangePermissionDialog(context),
                  icon: const Icon(Icons.admin_panel_settings),
                  label: const Text('등급 변경'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.secondary,
                    foregroundColor: Theme.of(context).colorScheme.onSecondary,
                  ),
                ),
              ),
            ),
          if (viewerPermissionLevel == 0)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.pushNamed(context, '/assignTags', arguments: targetPhoneNumber),
                  icon: const Icon(Icons.tag),
                  label: const Text('태그 할당'),
                ),
              ),
            ),
          if (viewerPermissionLevel <= 1)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _showRegisterNfcDialog(context, name),
                  icon: const Icon(Icons.nfc),
                  label: const Text('NFC 태그 등록'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueGrey,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          SizedBox(width: 60, child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold))),
          Expanded(child: SelectableText(value)),
        ],
      ),
    );
  }

  Widget _buildLeaderInfoRow(BuildContext context, String label, String phone) {
    if (phone.isEmpty) {
      return _buildInfoRow(label, '미지정');
    }

    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(phone).get(),
      builder: (context, snapshot) {
        String leaderName = '정보 없음';
        if (snapshot.hasData && snapshot.data!.exists) {
          final leaderData = snapshot.data!.data() as Map<String, dynamic>;
          leaderName = leaderData['name'] ?? '이름 없음';
        }
        return _buildInfoRow(label, leaderName);
      },
    );
  }
}

// MARK: - Prayer Request List Widget
class _PrayerRequestList extends StatelessWidget {
  final Stream<QuerySnapshot<Map<String, dynamic>>> prayerStream;
  final Function(String) onPrayerTap;
  final String viewerPhoneNumber;

  const _PrayerRequestList({
    required this.prayerStream,
    required this.onPrayerTap,
    required this.viewerPhoneNumber,
  });

  String _formatDateTime(Timestamp? ts) {
    if (ts == null) return '';
    final dt = ts.toDate();
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: prayerStream,
      builder: (context, prayerSnap) {
        if (prayerSnap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (prayerSnap.hasError || !prayerSnap.hasData) {
          return const Center(child: Text('기도제목을 불러오는 중 오류가 발생했습니다.'));
        }
        final prayerDocs = prayerSnap.data?.docs ?? [];
        if (prayerDocs.isEmpty) {
          return const Center(child: Text('작성한 기도제목이 없습니다.'));
        }

        return ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          itemCount: prayerDocs.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final doc = prayerDocs[index];
            final data = doc.data() as Map<String, dynamic>;
            final content = (data['content'] ?? '').toString();
            final createdAt = data['createdAt'] as Timestamp?;
            final List<dynamic> checkedBy = (data['checkedBy'] as List<dynamic>?) ?? [];
            final bool isChecked = checkedBy.contains(viewerPhoneNumber);

            return ListTile(
              title: Text(content, maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text(_formatDateTime(createdAt), style: const TextStyle(fontSize: 12)),
              trailing: Icon(
                isChecked ? Icons.check_circle : Icons.radio_button_unchecked,
                color: isChecked ? Colors.green : Colors.grey,
                size: 18,
              ),
              onTap: () => onPrayerTap(doc.id),
            );
          },
        );
      },
    );
  }
}
