import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../utils/user_utils.dart';
import 'admin_user_profile_screen.dart';

class AdminStudentTab extends StatefulWidget {
  final String phoneNumber; // 관리자 전화번호
  final int permissionLevel; // 관리자 권한

  const AdminStudentTab({
    super.key,
    required this.phoneNumber,
    required this.permissionLevel,
  });

  @override
  State<AdminStudentTab> createState() => _AdminStudentTabState();
}

class _AdminStudentTabState extends State<AdminStudentTab> {
  // 필터 상태 변수
  bool _isFilterExpanded = false;
  final List<String> _selectedYouthGroup = []; // 다중 선택
  final List<String> _selectedRole = []; // 다중 선택
  final List<String> _selectedTags = []; // 여러 태그 선택
  final TextEditingController _nameController = TextEditingController();
  bool _showUncheckedPrayerOnly = false;

  // 적용된 필터 값
  final List<String> _appliedYouthGroup = []; // 다중 적용
  final List<String> _appliedRole = []; // 다중 적용
  final List<String> _appliedTags = []; // 여러 태그 적용
  String _appliedName = '';
  bool _appliedShowUncheckedPrayerOnly = false;

  // 태그 데이터 (ID와 이름을 저장)
  List<Map<String, String>> _allTags = [];
  late Future<void> _tagsLoadingFuture;

  @override
  void initState() {
    super.initState();
    _tagsLoadingFuture = _loadTags();
  }

  // 태그 ID와 이름(name 필드)을 함께 로드
  Future<void> _loadTags() async {
    final snapshot = await FirebaseFirestore.instance.collection('tags').get();
    if (mounted) {
      setState(() {
        _allTags = snapshot.docs.map((doc) {
          final data = doc.data();
          // 'name' 필드가 있으면 사용하고, 없으면 ID를 이름으로 사용
          final name = data.containsKey('name') ? data['name'] as String : doc.id;
          return {'id': doc.id, 'name': name};
        }).toList();
      });
    }
  }

  Future<bool> _hasUncheckedPrayers(String userPhone) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('prayerRequests')
        .where('phoneNumber', isEqualTo: userPhone)
        .where('isChecked', isEqualTo: false)
        .limit(1)
        .get();
    return snapshot.docs.isNotEmpty;
  }

  String _getRoleName(int level) {
    switch (level) {
      case 2:
        return '청장';
      case 3:
        return '소그룹 리더';
      case 4:
        return '청년';
      default:
        return '정보 없음';
    }
  }

  void _applyFilters() {
    setState(() {
      _appliedYouthGroup.clear();
      _appliedYouthGroup.addAll(_selectedYouthGroup);
      _appliedRole.clear();
      _appliedRole.addAll(_selectedRole);
      _appliedTags.clear();
      _appliedTags.addAll(_selectedTags);
      _appliedName = _nameController.text;
      _appliedShowUncheckedPrayerOnly = _showUncheckedPrayerOnly;
      _isFilterExpanded = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    Query<Map<String, dynamic>> query = FirebaseFirestore.instance
        .collection('users')
        .where('permissionLevel', whereIn: [2, 3, 4])
        .orderBy('name');

    return Scaffold(
      appBar: AppBar(
        title: const Text('청년 관리'),
      ),
      // SingleChildScrollView를 추가하여 키보드 오버플로우 방지
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              _buildFilterSection(),
              const Divider(height: 1),
              // Expanded 제거
              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: query.snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return const Center(child: Text('청년 정보를 불러오는 중 오류가 발생했습니다.'));
                  }

                  var docs = snapshot.data?.docs ?? [];

                  // 필터링 로직
                  docs = docs.where((doc) {
                    final data = doc.data();
                    final birthRaw = (data['birthDate'] ?? '').toString();
                    final permissionLevel = (data['permissionLevel'] ?? 4) as int;
                    final name = (data['name'] ?? '').toString().toLowerCase();
                    final tags = (data['tags'] as List<dynamic>?)?.map((t) => t.toString()).toList() ?? [];

                    // 소속 필터 (다중 선택, OR)
                    if (_appliedYouthGroup.isNotEmpty) {
                      if (birthRaw.length >= 4) {
                        final birthYear = int.tryParse(birthRaw.substring(0, 4));
                        if (birthYear != null) {
                          final youthGroup = calculateYouthGroup(birthYear);
                          if (!_appliedYouthGroup.contains(youthGroup)) return false;
                        } else {
                          return false; // 생년 정보가 없으면 필터에 걸림
                        }
                      } else {
                        return false; // 생년 정보가 없으면 필터에 걸림
                      }
                    }

                    // 등급별 필터 (다중 선택, OR)
                    if (_appliedRole.isNotEmpty) {
                      if (!_appliedRole.contains(_getRoleName(permissionLevel))) return false;
                    }

                    // 태그별 필터 (다중 선택, OR 조건)
                    if (_appliedTags.isNotEmpty) {
                      // 선택된 태그들의 이름 목록을 가져옴
                      final appliedTagNames = _appliedTags.map((appliedId) {
                        return _allTags.firstWhere(
                          (tag) => tag['id'] == appliedId,
                          orElse: () => {'name': appliedId},
                        )['name']!;
                      }).toList();

                      // 사용자의 태그 중 하나라도 선택된 태그(ID 또는 이름)와 일치하는지 확인
                      final hasMatch = tags.any((userTag) =>
                          _appliedTags.contains(userTag) || appliedTagNames.contains(userTag));

                      if (!hasMatch) {
                        return false;
                      }
                    }

                    // 이름 검색 필터
                    if (_appliedName.isNotEmpty) {
                      if (!name.contains(_appliedName.toLowerCase())) return false;
                    }

                    return true;
                  }).toList();

                  // 미확인 기도제목 필터 (비동기 처리 필요)
                  if (_appliedShowUncheckedPrayerOnly) {
                    return FutureBuilder<List<DocumentSnapshot>>(
                      future: _filterByUncheckedPrayers(docs),
                      builder: (context, futureSnapshot) {
                        if (!futureSnapshot.hasData) {
                          return const Center(child: CircularProgressIndicator());
                        }
                        final filteredDocs = futureSnapshot.data!;
                        if (filteredDocs.isEmpty) {
                          return const Center(child: Text('조건에 맞는 청년이 없습니다.'));
                        }
                        return _buildUserListView(filteredDocs);
                      },
                    );
                  }

                  if (docs.isEmpty) {
                    return const Center(child: Text('조건에 맞는 청년이 없습니다.'));
                  }

                  return _buildUserListView(docs);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<List<DocumentSnapshot>> _filterByUncheckedPrayers(List<DocumentSnapshot> docs) async {
    List<DocumentSnapshot> filteredDocs = [];
    for (var doc in docs) {
      final phone = (doc.data() as Map<String, dynamic>)['phoneNumber'] ?? '';
      if (phone.isNotEmpty) {
        if (await _hasUncheckedPrayers(phone)) {
          filteredDocs.add(doc);
        }
      }
    }
    return filteredDocs;
  }

  Widget _buildFilterSection() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        children: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: Icon(_isFilterExpanded ? Icons.filter_list_off : Icons.filter_list),
              label: const Text('필터'),
              onPressed: () {
                setState(() {
                  _isFilterExpanded = !_isFilterExpanded;
                });
              },
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            child: _isFilterExpanded
                ? Container(
                    padding: const EdgeInsets.only(top: 8.0),
                    // 내부 SingleChildScrollView 제거
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildYouthGroupFilter(),
                        const SizedBox(height: 8),
                        _buildRoleFilter(),
                        const SizedBox(height: 8),
                        _buildTagFilter(),
                        const SizedBox(height: 8),
                        _buildNameFilter(),
                        const SizedBox(height: 8),
                        _buildUncheckedPrayerFilter(),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _applyFilters,
                            child: const Text('적용'),
                          ),
                        ),
                      ],
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _buildYouthGroupFilter() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('소속', style: TextStyle(fontWeight: FontWeight.bold)),
        Wrap(
          spacing: 8.0,
          children: ['1청', '2청', '3청'].map((group) {
            return FilterChip(
              label: Text(group),
              selected: _selectedYouthGroup.contains(group),
              onSelected: (selected) {
                setState(() {
                  if (selected) {
                    _selectedYouthGroup.add(group);
                  } else {
                    _selectedYouthGroup.remove(group);
                  }
                });
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildRoleFilter() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('등급', style: TextStyle(fontWeight: FontWeight.bold)),
        Wrap(
          spacing: 8.0,
          children: ['청장', '소그룹 리더', '청년'].map((role) {
            return FilterChip(
              label: Text(role),
              selected: _selectedRole.contains(role),
              onSelected: (selected) {
                setState(() {
                  if (selected) {
                    _selectedRole.add(role);
                  } else {
                    _selectedRole.remove(role);
                  }
                });
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildTagFilter() {
    return FutureBuilder<void>(
      future: _tagsLoadingFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && _allTags.isEmpty) {
          return const Center(child: CircularProgressIndicator(strokeWidth: 2));
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('태그', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Wrap(
              spacing: 8.0,
              children: _allTags.map((tag) {
                final tagId = tag['id']!;
                final tagName = tag['name']!;
                return FilterChip(
                  label: Text(tagName),
                  selected: _selectedTags.contains(tagId),
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        _selectedTags.add(tagId);
                      } else {
                        _selectedTags.remove(tagId);
                      }
                    });
                  },
                );
              }).toList(),
            ),
          ],
        );
      },
    );
  }

  Widget _buildNameFilter() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('이름 검색', style: TextStyle(fontWeight: FontWeight.bold)),
        TextFormField(
          controller: _nameController,
          decoration: const InputDecoration(hintText: '이름을 입력하세요'),
        ),
      ],
    );
  }

  Widget _buildUncheckedPrayerFilter() {
    return SwitchListTile(
      title: const Text('미확인 기도제목'),
      value: _showUncheckedPrayerOnly,
      onChanged: (value) {
        setState(() {
          _showUncheckedPrayerOnly = value;
        });
      },
    );
  }

  Widget _buildUserListView(List<DocumentSnapshot> docs) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: docs.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final data = docs[index].data() as Map<String, dynamic>;
        final name = (data['name'] ?? '이름 없음').toString();
        final phone = (data['phoneNumber'] ?? '').toString();
        final permissionLevel = (data['permissionLevel'] ?? 4) as int;
        final roleName = _getRoleName(permissionLevel);
        final userTags = (data['tags'] as List<dynamic>?)?.map((t) => t.toString()).toList() ?? [];

        final birthRaw = (data['birthDate'] ?? '').toString();
        String gisuText = '';
        String youthGroupText = '-';

        if (birthRaw.length >= 4) {
          final birthYear = int.tryParse(birthRaw.substring(0, 4));
          if (birthYear != null) {
            gisuText = '${calculateGisu(birthYear)}기';
            youthGroupText = calculateYouthGroup(birthYear);
          }
        }

        return ListTile(
          title: Row(
            children: [
              Text(name),
              const SizedBox(width: 8),
              FutureBuilder<bool>(
                future: _hasUncheckedPrayers(phone),
                builder: (context, prayerSnapshot) {
                  if (prayerSnapshot.data == true) {
                    return const Icon(Icons.circle, color: Colors.red, size: 10);
                  }
                  return const SizedBox.shrink();
                },
              ),
            ],
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('$roleName / $gisuText / $youthGroupText'),
              if (userTags.isNotEmpty)
                Wrap(
                  spacing: 4.0,
                  runSpacing: 4.0,
                  // 태그 ID 또는 이름을 이름으로 변환하여 표시
                  children: userTags.map((tagValue) {
                     // tagValue는 ID일수도, 이름일수도 있음
                    final tagName = _allTags.firstWhere(
                      (tagMap) => tagMap['id'] == tagValue || tagMap['name'] == tagValue,
                      orElse: () => {'name': tagValue}, // 태그를 찾지 못하면 원래 값 표시
                    )['name'];
                    return Chip(
                      label: Text(tagName!, style: const TextStyle(fontSize: 10)),
                      padding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                    );
                  }).toList(),
                ),
            ],
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            Navigator.pushNamed(
              context,
              '/adminUserProfile',
              arguments: AdminUserProfileArguments(
                targetPhoneNumber: phone,
                viewerPhoneNumber: widget.phoneNumber,
                viewerPermissionLevel: widget.permissionLevel,
              ),
            );
          },
        );
      },
    );
  }
}
