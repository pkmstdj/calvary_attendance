import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../screens/prayer/prayer_detail_screen.dart';
import '../../utils/age_utils.dart';
import '../../utils/department_utils.dart';
import '../../utils/phone_utils.dart';
import '../../utils/team_utils.dart';
import '../../utils/user_utils.dart';

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
  State<AdminUserProfileScreen> createState() => _AdminUserProfileScreenState();
}

class _AdminUserProfileScreenState extends State<AdminUserProfileScreen> {
  late Future<DocumentSnapshot<Map<String, dynamic>>> _userFuture;
  late final AdminUserProfileArguments _args;
  bool _initialized = false;
  String? _targetUserDocId;

  Map<String, String> _smallGroupLeaders = {};
  final Map<String, String> _leaderNameCache = {};

  @override
  void initState() {
    super.initState();
    _fetchSmallGroupLeaders();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      final args = ModalRoute.of(context)!.settings.arguments;
      if (args is AdminUserProfileArguments) {
        _args = args;
        _loadUser();
        _initialized = true;
      }
    }
  }

  void _loadUser() {
    setState(() {
      _userFuture = _getUserDocument();
    });
  }
  
  Future<DocumentSnapshot<Map<String, dynamic>>> _getUserDocument() async {
     if (_targetUserDocId != null) {
       return FirebaseFirestore.instance.collection('users').doc(_targetUserDocId).get();
     }
     final snapshot = await FirebaseFirestore.instance
            .collection('users')
            .where('phoneNumber', isEqualTo: _args.targetPhoneNumber)
            .limit(1)
            .get();
      if (snapshot.docs.isNotEmpty) {
        _targetUserDocId = snapshot.docs.first.id;
        return snapshot.docs.first;
      }
      throw Exception('User not found');
  }

  Future<void> _fetchSmallGroupLeaders() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('permissionLevel', isEqualTo: 2)
          .orderBy('name')
          .get();

      final leaders = <String, String>{};
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final name = data['name'] ?? '이름 없음';
        final classYear = data['classYear'] ?? '??';
        final phoneNumber = data['phoneNumber'];
        if (phoneNumber != null) {
          leaders[phoneNumber] = '$classYear기 $name';
        }
      }

      if (mounted) {
        setState(() {
          _smallGroupLeaders = leaders;
        });
      }
    } catch (e) {
      // 에러 처리
    }
  }
  
  Future<String> _getLeaderDisplayName(String phoneNumber) async {
    if (_leaderNameCache.containsKey(phoneNumber)) {
      return _leaderNameCache[phoneNumber]!;
    }
    
    if (_smallGroupLeaders.containsKey(phoneNumber)) {
        final name = _smallGroupLeaders[phoneNumber]!;
        _leaderNameCache[phoneNumber] = name;
        return name;
    }

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('phoneNumber', isEqualTo: phoneNumber)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        final data = snapshot.docs.first.data();
        final name = data['name'] ?? '이름 없음';
        final classYear = data['classYear'] ?? '??';
        final displayName = '$classYear기 $name';
        _leaderNameCache[phoneNumber] = displayName;
        return displayName;
      }
    } catch (e) {
      return '정보 없음';
    }
    return '정보 없음';
  }

  Future<void> _updateBirthDate(String newDate) async {
    if (_targetUserDocId == null) return;
    
    // 기수 자동 계산
    final newClassYear = AgeCalculator.calculateClassYear(newDate);

    await FirebaseFirestore.instance
        .collection('users')
        .doc(_targetUserDocId)
        .update({
          'birthDate': newDate,
          'classYear': newClassYear,
        });
    _loadUser();
  }

  Future<void> _updatePhoneNumber(String newPhone) async {
    if (_targetUserDocId == null) return;
    await FirebaseFirestore.instance
        .collection('users')
        .doc(_targetUserDocId)
        .update({'phoneNumber': newPhone});
    _loadUser();
  }

  Future<void> _showEditBirthDateDialog(String? currentBirthDate) async {
    DateTime initialDate = DateTime.now();
    if (currentBirthDate != null && currentBirthDate.isNotEmpty) {
      try {
        initialDate = DateTime.parse(currentBirthDate);
      } catch (_) {}
    }

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
       final String formatted = DateFormat('yyyy-MM-dd').format(picked);
       _updateBirthDate(formatted);
    }
  }

  Future<void> _showEditPhoneNumberDialog(String currentPhoneNumber) async {
    final controller = TextEditingController(text: currentPhoneNumber);
    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('전화번호 수정'),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(labelText: '전화번호 (- 없이 입력)'),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
            TextButton(
              onPressed: () {
                if (controller.text.isNotEmpty) {
                  _updatePhoneNumber(controller.text.trim());
                  Navigator.pop(context);
                }
              },
              child: const Text('저장'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteUser() async {
    // 삭제 로직 (필요시 구현)
  }

  Future<void> _changePermission(int newLevel) async {
    if (_targetUserDocId == null) return;
    await FirebaseFirestore.instance
        .collection('users')
        .doc(_targetUserDocId)
        .update({'permissionLevel': newLevel});
    _loadUser();
  }

  Future<void> _changeSmallGroup(String leaderPhoneNumber) async {
    if (_targetUserDocId == null) return;
    await FirebaseFirestore.instance
        .collection('users')
        .doc(_targetUserDocId)
        .update({'smallGroupLeaderPhone': leaderPhoneNumber});
    _loadUser();
  }

  Future<void> _updateUserTags(List<String> newTags) async {
    if (_targetUserDocId == null) return;
    await FirebaseFirestore.instance
        .collection('users')
        .doc(_targetUserDocId)
        .update({'tags': newTags});
    _loadUser();
  }

  void _showEditTagsDialog(List<String> currentTags) {
    List<String> selectedTags = List.from(currentTags);
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('사역팀 수정'),
          content: StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
              return SingleChildScrollView(
                child: Wrap(
                  spacing: 6.0,
                  children: TeamUtils.allTeams.map((team) {
                    return FilterChip(
                      label: Text(team),
                      selected: selectedTags.contains(team),
                      onSelected: (isSelected) {
                        setState(() {
                          isSelected ? selectedTags.add(team) : selectedTags.remove(team);
                        });
                      },
                    );
                  }).toList(),
                ),
              );
            },
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
            TextButton(onPressed: () { _updateUserTags(selectedTags); Navigator.pop(context); }, child: const Text('저장')),
          ],
        );
      },
    );
  }

  void _showPrayerDetail(String prayerDocId, String text, String? date, bool isChecked) {
    if (_args.viewerPermissionLevel == 0 && !isChecked) {
       if (_targetUserDocId != null) {
        FirebaseFirestore.instance
          .collection('users')
          .doc(_targetUserDocId)
          .collection('prayerRequests')
          .doc(prayerDocId)
          .update({'isChecked': true});
       }
    }
    
    Navigator.of(context).push(MaterialPageRoute(
      builder: (context) => const PrayerDetailScreen(),
      settings: RouteSettings(
        arguments: PrayerDetailScreenArguments(
          userDocId: _targetUserDocId!,
          prayerDocId: prayerDocId,
          text: text,
          date: date,
          isOwner: false, 
        ),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return const Scaffold(body: Center(child: Text('잘못된 접근입니다.')));
    }

    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: _userFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (snapshot.hasError || !snapshot.hasData || !snapshot.data!.exists) {
          return const Scaffold(body: Center(child: Text('사용자 정보를 불러올 수 없습니다.')));
        }

        final userDoc = snapshot.data!;
        final data = userDoc.data()!;
        _targetUserDocId = userDoc.id;
        
        final name = (data['name'] ?? '이름 없음').toString();
        final birthDate = data['birthDate'] as String?;
        final age = AgeCalculator.calculateInternationalAge(birthDate);
        final classYear = (data['classYear'] ?? '').toString();
        final department = DepartmentCalculator.calculateDepartment(birthDate);
        
        final rawPhoneNumber = data['phoneNumber'] as String? ?? _args.targetPhoneNumber;
        final formattedPhone = formatPhoneNumber(rawPhoneNumber);
        
        final permissionLevel = (data['permissionLevel'] ?? 4) as int;
        final smallGroupLeaderPhone = data['smallGroupLeaderPhone'] as String?;
        final tags = (data['tags'] as List<dynamic>? ?? []).map((tag) => tag.toString()).toList();

        final bool canEditLevel = _args.viewerPermissionLevel < 1;
        final bool canEditGroup = _args.viewerPermissionLevel < 3;
        final bool isSelf = _args.viewerPhoneNumber == rawPhoneNumber;
        final bool isAdmin = _args.viewerPermissionLevel < 1 && permissionLevel > 0;
        final bool canEditBasicInfo = _args.viewerPermissionLevel == 0;

        return Scaffold(
          appBar: AppBar(title: Text(name), actions: [
             if (isAdmin && !isSelf)
                PopupMenuButton<String>(
                  onSelected: (value) => (value == 'delete') ? _deleteUser() : null,
                  itemBuilder: (context) => [const PopupMenuItem(value: 'delete', child: Text('사용자 삭제'))],
                ),
          ],),
          body: SafeArea(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildInfoCard(
                      title: '기본 정보', 
                      details: {
                        '소속': department, '기수': classYear, '나이': age > 0 ? '$age세' : '정보 없음',
                        '생년월일': birthDate ?? '정보 없음', '전화번호': formattedPhone,
                      },
                      editActions: canEditBasicInfo ? {
                        '생년월일': () => _showEditBirthDateDialog(birthDate),
                        '전화번호': () => _showEditPhoneNumberDialog(rawPhoneNumber),
                      } : null,
                    ),
                    const SizedBox(height: 24),
                    _buildPermissionCard(
                      currentLevel: permissionLevel, canEdit: canEditLevel,
                      onChanged: (newLevel) => _changePermission(newLevel),
                    ),
                    const SizedBox(height: 24),
                    if (permissionLevel >= 1 && permissionLevel <= 3) ...[
                      _buildSmallGroupCard(
                        leaderPhone: smallGroupLeaderPhone, canEdit: canEditGroup,
                        leaders: _smallGroupLeaders, onChanged: (newLeaderPhone) => _changeSmallGroup(newLeaderPhone),
                      ),
                      const SizedBox(height: 24),
                    ],
                    _buildTagsCard(tags: tags, canEdit: isAdmin, onEdit: () => _showEditTagsDialog(tags)),
                    
                    if (_args.viewerPermissionLevel == 0 && _targetUserDocId != null) ...[
                      const SizedBox(height: 24),
                      _buildPrayerRequestsCard(_targetUserDocId!),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildInfoCard({
    required String title, 
    required Map<String, String> details,
    Map<String, VoidCallback>? editActions,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const Divider(height: 24),
            ...details.entries.map((e) {
              final action = editActions?[e.key];
              return Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(e.key, style: const TextStyle(color: Colors.grey)), 
                    Row(
                      children: [
                        Text(e.value),
                        if (action != null) ...[
                          const SizedBox(width: 8),
                          InkWell(
                            onTap: action,
                            child: const Icon(Icons.edit, size: 16, color: Colors.blue),
                          )
                        ]
                      ],
                    )
                  ],
                ),
              );
            })
          ],
        ),
      ),
    );
  }

  Widget _buildPermissionCard({required int currentLevel, required bool canEdit, required ValueChanged<int> onChanged}) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('등급', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(getPermissionLabel(currentLevel)),
                if (canEdit)
                  PopupMenuButton<int>(
                    child: const Icon(Icons.edit),
                    onSelected: onChanged,
                    itemBuilder: (context) => [
                      // const PopupMenuItem(value: 0, child: Text('사역자')),
                      const PopupMenuItem(value: 1, child: Text('청장')),
                      const PopupMenuItem(value: 2, child: Text('리더')),
                      const PopupMenuItem(value: 3, child: Text('청년')),
                    ],
                  )
              ],
            )
          ],
        ),
      ),
    );
  }
  
  Widget _buildSmallGroupCard({
    String? leaderPhone,
    required bool canEdit,
    required Map<String, String> leaders,
    required ValueChanged<String> onChanged,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('소그룹', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (leaderPhone == null || leaderPhone.isEmpty)
                  const Text('소속 없음')
                else
                  FutureBuilder<String>(
                    future: _getLeaderDisplayName(leaderPhone),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2.0));
                      }
                      return Expanded(child: Text(snapshot.data ?? '정보 없음', overflow: TextOverflow.ellipsis));
                    },
                  ),
                if (canEdit)
                  PopupMenuButton<String>(
                    child: const Icon(Icons.edit),
                    onSelected: onChanged,
                    itemBuilder: (context) => leaders.entries.map((entry) {
                      return PopupMenuItem(
                        value: entry.key,
                        child: Text(entry.value),
                      );
                    }).toList(),
                  )
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildTagsCard({required List<String> tags, required bool canEdit, required VoidCallback onEdit}) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
             Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('사역팀', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                if (canEdit)
                  IconButton(icon: const Icon(Icons.edit), onPressed: onEdit, tooltip: '사역팀 수정',)
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8.0,
              runSpacing: 4.0,
              children: tags.isNotEmpty 
                ? tags.map((tag) => Chip(label: Text(tag))).toList()
                : [const Text('사역팀이 없습니다.')],
            )
          ],
        ),
      ),
    );
  }
  
  Widget _buildPrayerRequestsCard(String userId) {
    final stream = FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('prayerRequests')
        .orderBy('createdAt', descending: true)
        .snapshots();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('기도제목', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const Divider(height: 24),
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: stream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Text('작성된 기도제목이 없습니다.');
                }
                
                final requests = snapshot.data!.docs;

                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: requests.length,
                  itemBuilder: (context, index) {
                    final requestDoc = requests[index];
                    final data = requestDoc.data();
                    final text = data['text'] as String? ?? '내용 없음';
                    final isChecked = data['isChecked'] as bool? ?? false;
                    final timestamp = data['createdAt'] as Timestamp?;
                    final dateString = timestamp != null
                        ? DateFormat('yyyy-MM-dd HH:mm').format(timestamp.toDate())
                        : null;

                    return ListTile(
                      leading: Icon(
                        isChecked ? Icons.check_circle : Icons.circle_outlined,
                        color: isChecked ? Colors.green : Colors.grey,
                      ),
                      title: Text(
                        text,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          decoration: isChecked ? TextDecoration.lineThrough : null,
                          color: isChecked ? Colors.grey : null,
                        ),
                      ),
                      onTap: () => _showPrayerDetail(requestDoc.id, text, dateString, isChecked),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
