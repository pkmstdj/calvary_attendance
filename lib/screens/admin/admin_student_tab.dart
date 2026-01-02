import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../utils/department_utils.dart';
import '../../utils/team_utils.dart';
import '../../utils/user_utils.dart';
import 'admin_user_profile_screen.dart';

class AdminStudentTab extends StatefulWidget {
  final String viewerPhoneNumber;
  final int viewerPermissionLevel;

  const AdminStudentTab({
    super.key,
    required this.viewerPhoneNumber,
    required this.viewerPermissionLevel,
  });

  @override
  State<AdminStudentTab> createState() => _AdminStudentTabState();
}

class _AdminStudentTabState extends State<AdminStudentTab> {
  List<DocumentSnapshot> _allUsers = [];
  List<DocumentSnapshot> _foundUsers = [];
  final TextEditingController _searchController = TextEditingController();

  // 필터 및 정렬 상태 변수
  bool _isFilterPanelVisible = false;
  Set<String> _selectedDepartments = {};
  Set<int> _selectedPermissionLevels = {};
  Set<String> _selectedTags = {};
  bool _hasPrayerRequestFilter = false;
  String _sortBy = 'name';

  @override
  void initState() {
    super.initState();
    _loadAllUsers();
  }

  Future<void> _loadAllUsers() async {
    final QuerySnapshot snapshot = await FirebaseFirestore.instance
        .collection('users')
        .where('permissionLevel', isNotEqualTo: 0)
        .orderBy('permissionLevel')
        .orderBy('name')
        .get();
    if (mounted) {
      setState(() {
        _allUsers = snapshot.docs;
        _runFilter();
      });
    }
  }

  void _sortUsersByClassYear() {
    List<DocumentSnapshot> sortedList = List.from(_allUsers);
    sortedList.sort((aDoc, bDoc) {
      final aData = aDoc.data() as Map<String, dynamic>;
      final bData = bDoc.data() as Map<String, dynamic>;

      final pA = aData['permissionLevel'] ?? 4;
      final pB = bData['permissionLevel'] ?? 4;
      int pCompare = pA.compareTo(pB);
      if (pCompare != 0) return pCompare;

      final cA = int.tryParse(aData['classYear'] ?? '0') ?? 0;
      final cB = int.tryParse(bData['classYear'] ?? '0') ?? 0;
      int cCompare = cB.compareTo(cA);
      if (cCompare != 0) return cCompare;

      final nA = aData['name'] ?? '';
      final nB = bData['name'] ?? '';
      return nA.compareTo(nB);
    });
    if (mounted) {
      setState(() {
        _allUsers = sortedList;
        _runFilter();
      });
    }
  }

  void _runFilter() {
    List<DocumentSnapshot> results = List.from(_allUsers);
    String searchTerm = _searchController.text.toLowerCase();

    if (searchTerm.isNotEmpty) {
      results = results.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final name = (data['name'] ?? '').toString().toLowerCase();
        return name.contains(searchTerm);
      }).toList();
    }

    if (_selectedDepartments.isNotEmpty) {
      results = results.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final birthDate = data['birthDate'] as String?;
        final department = DepartmentCalculator.calculateDepartment(birthDate);
        return _selectedDepartments.contains(department);
      }).toList();
    }

    if (_selectedPermissionLevels.isNotEmpty) {
      results = results.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final permissionLevel = data['permissionLevel'] ?? -1;
        return _selectedPermissionLevels.contains(permissionLevel);
      }).toList();
    }
    
    if (_selectedTags.isNotEmpty) {
      results = results.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final userTags = (data['tags'] as List<dynamic>? ?? []).map((t) => t.toString()).toList();
        return userTags.any((tag) => _selectedTags.contains(tag));
      }).toList();
    }

    if (mounted) {
      setState(() {
        _foundUsers = results;
      });
    }
  }

  void _applyFiltersAndCollapse() {
    setState(() {
      _isFilterPanelVisible = false;
    });
    _runFilter();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('전체 명단'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () {
              setState(() {
                _isFilterPanelVisible = !_isFilterPanelVisible;
              });
            },
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.sort),
            onSelected: (value) {
              if (_sortBy == value) return;
              setState(() {
                _sortBy = value;
              });
              if (value == 'name') {
                _loadAllUsers();
              } else if (value == 'classYear') {
                _sortUsersByClassYear();
              }
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              const PopupMenuItem<String>(value: 'name', child: Text('이름 정렬')),
              const PopupMenuItem<String>(value: 'classYear', child: Text('기수 정렬')),
            ],
          ),
        ],
      ),
      body: SafeArea(child: RefreshIndicator(
        onRefresh: _loadAllUsers,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(), // 스크롤 내용이 적어도 리프레시 가능하도록 설정
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: '이름으로 검색...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Colors.grey[200],
                  ),
                  onChanged: (value) => _runFilter(),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                height: _isFilterPanelVisible ? null : 0,
                child: _buildFilterPanel(),
              ),
            ),
            _foundUsers.isNotEmpty
                ? SliverList(
              delegate: SliverChildBuilderDelegate(
                    (context, index) {
                  final user = _foundUsers[index];
                  final data = user.data() as Map<String, dynamic>;
                  final name = data['name'] ?? '이름 없음';
                  final classYear = data['classYear'] ?? '??';
                  final permissionLevel = data['permissionLevel'] ?? 4;
                  final permissionLabel = getPermissionLabel(permissionLevel);
                  final tags = (data['tags'] as List<dynamic>? ?? []).map((t) => t.toString()).toList();

                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: ListTile(
                      title: Text(name),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('$classYear기 / $permissionLabel'),
                          if (tags.isNotEmpty)
                            Wrap(
                              spacing: 4.0,
                              runSpacing: 2.0,
                              children: tags.map((tag) => Chip(
                                label: Text(tag, style: const TextStyle(fontSize: 10)),
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                                visualDensity: VisualDensity.compact,
                              )).toList(),
                            )
                        ],
                      ),
                      onTap: () {
                        final targetPhoneNumber = data['phoneNumber'];
                        if (targetPhoneNumber != null) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const AdminUserProfileScreen(),
                              settings: RouteSettings(
                                arguments: AdminUserProfileArguments(
                                  targetPhoneNumber: targetPhoneNumber,
                                  viewerPhoneNumber: widget.viewerPhoneNumber,
                                  viewerPermissionLevel: widget.viewerPermissionLevel,
                                ),
                              ),
                            ),
                          );
                        }
                      },
                    ),
                  );
                },
                childCount: _foundUsers.length,
              ),
            )
                : const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(child: Text('검색 결과가 없습니다.', style: TextStyle(fontSize: 18))),
            ),
          ],
        ),
      ),
      ),

    );
  }

  Widget _buildFilterPanel() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildFilterSection('소속', ['1청', '2청', '3청'], _selectedDepartments, (value) {
              setState(() {
                _selectedDepartments.contains(value)
                    ? _selectedDepartments.remove(value)
                    : _selectedDepartments.add(value);
              });
            }),
            const Divider(),
            _buildFilterSection('등급', {1: '청장', 2: '리더', 3: '청년'}, _selectedPermissionLevels, (value) {
               setState(() {
                _selectedPermissionLevels.contains(value)
                    ? _selectedPermissionLevels.remove(value)
                    : _selectedPermissionLevels.add(value);
              });
            }),
            const Divider(),
            _buildFilterSection('사역팀', TeamUtils.allTeams, _selectedTags, (value) {
              setState(() {
                _selectedTags.contains(value)
                    ? _selectedTags.remove(value)
                    : _selectedTags.add(value);
              });
            }),
            const Divider(),
            _buildPrayerRequestFilter(),
            const SizedBox(height: 4),
            ElevatedButton(
              onPressed: _applyFiltersAndCollapse,
              child: const Center(child: Text('필터 적용')),
            ),
            const Divider(),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterSection(String title, dynamic options, Set selectedValues, Function(dynamic) onSelected) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6.0,
          children: (options is List<String> ? options : (options as Map).keys).map<Widget>((key) {
            final label = options is List<String> ? key : options[key]!;
            final value = options is List<String> ? key : key;
            return FilterChip(
              label: Text(label),
              selected: selectedValues.contains(value),
              onSelected: (isSelected) => onSelected(value),
            );
          }).toList(),
        ),
      ],
    );
  }
  
  Widget _buildPrayerRequestFilter() {
    return Row(
      children: [
        const Text('기도제목', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const Spacer(),
        Checkbox(
          value: _hasPrayerRequestFilter,
          onChanged: (bool? value) {
            if (value != null) {
              setState(() {
                _hasPrayerRequestFilter = value;
              });
            }
          },
        ),
      ],
    );
  }
}
