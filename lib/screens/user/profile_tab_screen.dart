import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../utils/phone_utils.dart';
import '../../utils/date_utils.dart';
import '../../utils/user_utils.dart';

class ProfileTabScreen extends StatelessWidget {
  final String phoneNumber;

  const ProfileTabScreen({
    super.key,
    required this.phoneNumber,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('users').doc(phoneNumber).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Text('오류가 발생했습니다: ${snapshot.error}'),
          );
        }

        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const Center(
            child: Text('사용자 정보를 찾을 수 없습니다.'),
          );
        }

        final data = snapshot.data!.data();
        final name = (data?['name'] ?? '이름 없음').toString();
        final birthRaw = (data?['birthDate'] ?? '').toString();
        final birth = formatBirthDate(birthRaw);
        final permissionLevel = (data?['permissionLevel'] ?? 5) as int;
        final leaderPhone = (data?['smallGroupLeaderPhone'] ?? '').toString();

        final formattedPhone = formatPhoneNumber(phoneNumber);
        
        String gisuText = '-';
        String youthGroupText = '-';

        // 관리자가 아닐 때만 기수/소속 계산
        if (permissionLevel > 1 && birthRaw.length >= 4) {
            final birthYear = int.tryParse(birthRaw.substring(0, 4));
            if (birthYear != null) {
              gisuText = '${calculateGisu(birthYear)}기';
              youthGroupText = calculateYouthGroup(birthYear);
            }
        }

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Divider(height: 24),
                        _buildProfileInfoRow('생년월일', birth.isNotEmpty ? birth : '-'),
                        _buildProfileInfoRow('전화번호', formattedPhone.isNotEmpty ? formattedPhone : '-'),
                        _buildProfileInfoRow('기수', gisuText),
                        _buildProfileInfoRow('소속', youthGroupText),
                        _buildLeaderInfoRow('소그룹', leaderPhone),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pushNamed(context, '/editProfile', arguments: phoneNumber);
                  },
                  icon: const Icon(Icons.edit),
                  label: const Text('프로필 수정'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildProfileInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          Text(
            value,
            style: const TextStyle(fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildLeaderInfoRow(String label, String phone) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          (phone.isEmpty)
            ? const Text('미지정', style: TextStyle(fontSize: 16))
            : StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance.collection('users').doc(phone).snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData || !snapshot.data!.exists) {
                    return const Text('정보 없음', style: TextStyle(fontSize: 16));
                  }
                  final leaderName = snapshot.data!['name'] ?? '리더 정보 없음';
                  return Text(leaderName, style: const TextStyle(fontSize: 16));
                },
              ),
        ],
      ),
    );
  }
}
