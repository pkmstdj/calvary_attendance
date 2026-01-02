import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../admin/admin_user_profile_screen.dart';

class GroupManagementTabScreen extends StatefulWidget {
  final String leaderPhoneNumber;

  const GroupManagementTabScreen({
    super.key,
    required this.leaderPhoneNumber,
  });

  @override
  State<GroupManagementTabScreen> createState() => _GroupManagementTabScreenState();
}

class _GroupManagementTabScreenState extends State<GroupManagementTabScreen> {
  DateTime _selectedDate = DateTime.now();
  String? _leaderUid;

  @override
  void initState() {
    super.initState();
    _fetchLeaderUid();
  }

  Future<void> _fetchLeaderUid() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('phoneNumber', isEqualTo: widget.leaderPhoneNumber)
          .limit(1)
          .get();
      
      if (snapshot.docs.isNotEmpty) {
        if (mounted) {
          setState(() {
            _leaderUid = snapshot.docs.first.id;
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching leader UID: $e');
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2101),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  // 출석 체크/해제 로직
  Future<void> _toggleAttendance(Map<String, dynamic> member, bool isCurrentlyAttended, String docId) async {
    final year = DateFormat('yyyy').format(_selectedDate);
    final monthDay = DateFormat('MM-dd').format(_selectedDate);
    final dateString = DateFormat('yyyy-MM-dd').format(_selectedDate);
    
    // member의 문서 ID (docId)를 사용하여 출석 문서 경로 설정
    final attendanceDocRef = FirebaseFirestore.instance
        .collection('group_attendance')
        .doc(year)
        .collection(monthDay)
        .doc(docId);

    if (isCurrentlyAttended) {
      // 출석 해제 (삭제 확인 다이얼로그)
      final bool? confirm = await showDialog<bool>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('출석 취소'),
            content: Text('${member['name']} 님의 출석 정보를 삭제하시겠습니까?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('취소'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('삭제', style: TextStyle(color: Colors.red)),
              ),
            ],
          );
        },
      );

      if (confirm == true) {
        await attendanceDocRef.delete();
      }
    } else {
      // 리더 UID가 아직 로드되지 않았으면 전화번호를 임시로 사용하거나 다시 조회 시도
      String checkerId = _leaderUid ?? widget.leaderPhoneNumber;
      
      // 출석 체크
      await attendanceDocRef.set({
        'date': dateString,
        'timestamp': Timestamp.fromDate(DateTime.now()), // 체크한 시점
        'userId': docId,
        'checkedBy': checkerId, // 체크한 사람(리더)의 UID (없으면 전화번호)
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final year = DateFormat('yyyy').format(_selectedDate);
    final monthDay = DateFormat('MM-dd').format(_selectedDate);

    // 1. 소그룹 멤버 쿼리
    final membersQuery = FirebaseFirestore.instance
        .collection('users')
        .where('smallGroupLeaderPhone', isEqualTo: widget.leaderPhoneNumber);

    // 2. 해당 날짜의 출석 데이터 쿼리
    final attendanceQuery = FirebaseFirestore.instance
        .collection('group_attendance')
        .doc(year)
        .collection(monthDay);

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.all(16.0),
              child:
              Text(
                '소그룹 출결',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
            ),
            // 날짜 선택 헤더
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    DateFormat('yyyy년 MM월 dd일').format(_selectedDate),
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  ElevatedButton(
                    onPressed: () => _selectDate(context),
                    child: const Text('날짜 변경'),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            
            // 멤버 리스트 및 출석 현황
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: membersQuery.snapshots(),
                builder: (context, membersSnapshot) {
                  if (membersSnapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (membersSnapshot.hasError) {
                    return Center(child: Text('멤버 로드 오류: ${membersSnapshot.error}'));
                  }
                  
                  // Firestore QuerySnapshot을 리스트로 변환 후 정렬
                  final members = membersSnapshot.data?.docs ?? [];
                  
                  members.sort((a, b) {
                    final dataA = a.data();
                    final dataB = b.data();
                    
                    // 1. 리더(본인) 최우선
                    final bool isLeaderA = dataA['phoneNumber'] == widget.leaderPhoneNumber;
                    final bool isLeaderB = dataB['phoneNumber'] == widget.leaderPhoneNumber;
                    if (isLeaderA && !isLeaderB) return -1;
                    if (!isLeaderA && isLeaderB) return 1;

                    // 2. 기수 높은 순 (오름차순)
                    final int classA = int.tryParse(dataA['classYear']?.toString() ?? '0') ?? 0;
                    final int classB = int.tryParse(dataB['classYear']?.toString() ?? '0') ?? 0;
                    if (classA != classB) {
                      return classA.compareTo(classB); // 오름차순
                    }

                    // 3. 이름 순 (오름차순)
                    final String nameA = dataA['name']?.toString() ?? '';
                    final String nameB = dataB['name']?.toString() ?? '';
                    return nameA.compareTo(nameB);
                  });

                  if (members.isEmpty) {
                    return const Center(child: Text('소속된 그룹원이 없습니다.'));
                  }

                  // 출석 데이터 스트림 구독
                  return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: attendanceQuery.snapshots(),
                    builder: (context, attendanceSnapshot) {
                      final Set<String> attendedUserIds = {};
                      if (attendanceSnapshot.hasData) {
                        for (var doc in attendanceSnapshot.data!.docs) {
                          attendedUserIds.add(doc.id);
                        }
                      }

                      return ListView.separated(
                        itemCount: members.length,
                        separatorBuilder: (context, index) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final memberDoc = members[index];
                          final memberData = memberDoc.data();
                          final memberId = memberDoc.id;
                          final memberName = memberData['name'] ?? '이름 없음';
                          final memberPhone = memberData['phoneNumber'] ?? '';
                          final classYear = memberData['classYear'] ?? '';

                          final isAttended = attendedUserIds.contains(memberId);

                          return ListTile(
                            leading: Checkbox(
                              activeColor: Colors.green,
                              value: isAttended,
                              onChanged: (bool? value) {
                                _toggleAttendance(memberData, isAttended, memberId);
                              },
                            ),
                            title: Text('$memberName ($classYear기)'),
                            subtitle: Text(memberPhone),
                            trailing: IconButton(
                              icon: const Icon(Icons.info_outline),
                              onPressed: () {
                                Navigator.pushNamed(
                                  context,
                                  '/adminUserProfile',
                                  arguments: AdminUserProfileArguments(
                                    targetPhoneNumber: memberPhone,
                                    viewerPhoneNumber: widget.leaderPhoneNumber,
                                    viewerPermissionLevel: 3, // 리더 권한
                                  ),
                                );
                              },
                            ),
                            onTap: () {
                               _toggleAttendance(memberData, isAttended, memberId);
                            },
                          );
                        },
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
