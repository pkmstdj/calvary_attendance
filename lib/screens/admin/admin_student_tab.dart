import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../utils/age_utils.dart';
import '../../utils/department_utils.dart';
import '../../utils/phone_utils.dart';
import 'admin_user_profile_screen.dart';

class AdminStudentTab extends StatefulWidget {
  final String phoneNumber;
  final int permissionLevel;

  const AdminStudentTab({
    super.key,
    required this.phoneNumber,
    required this.permissionLevel,
  });

  @override
  State<AdminStudentTab> createState() => _AdminStudentTabState();
}

class _AdminStudentTabState extends State<AdminStudentTab> {
  String _searchQuery = '';
  String _sortOrder = 'name'; // 'name', 'classYear', 'department'
  List<String> _departmentFilters = [];

  // Firestore에서 모든 청년 목록을 가져옵니다.
  Stream<QuerySnapshot<Map<String, dynamic>>> _getUsersStream() {
    return FirebaseFirestore.instance.collection('users').snapshots();
  }

  // 검색 쿼리와 필터에 따라 사용자를 필터링합니다.
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _filterAndSortUsers(
      List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    List<QueryDocumentSnapshot<Map<String, dynamic>>> filteredDocs = docs;

    // 검색 쿼리 필터링
    if (_searchQuery.isNotEmpty) {
      filteredDocs = filteredDocs.where((doc) {
        final name = doc.data()['name']?.toString().toLowerCase() ?? '';
        final phone = doc.data()['phoneNumber']?.toString() ?? '';
        final query = _searchQuery.toLowerCase();
        return name.contains(query) || phone.contains(query);
      }).toList();
    }

    // 부서 필터링
    if (_departmentFilters.isNotEmpty) {
      filteredDocs = filteredDocs.where((doc) {
        final birthDate = doc.data()['birthDate'] as String?;
        // 수정: DepartmentCalculator 사용
        final department = DepartmentCalculator.calculateDepartment(birthDate);
        return _departmentFilters.contains(department);
      }).toList();
    }

    // 정렬
    filteredDocs.sort((a, b) {
      final dataA = a.data();
      final dataB = b.data();

      if (_sortOrder == 'name') {
        return (dataA['name'] ?? '').compareTo(dataB['name'] ?? '');
      } else if (_sortOrder == 'classYear') {
        final classYearA = int.tryParse(dataA['classYear'] ?? '999') ?? 999;
        final classYearB = int.tryParse(dataB['classYear'] ?? '999') ?? 999;
        return classYearA.compareTo(classYearB);
      } else if (_sortOrder == 'department') {
        final birthDateA = dataA['birthDate'] as String?;
        final birthDateB = dataB['birthDate'] as String?;
        // 수정: DepartmentCalculator 사용
        final departmentA = DepartmentCalculator.calculateDepartment(birthDateA);
        final departmentB = DepartmentCalculator.calculateDepartment(birthDateB);
        return departmentA.compareTo(departmentB);
      }
      return 0;
    });

    return filteredDocs;
  }

  // 필터 다이얼로그 표시
  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) {
        List<String> tempFilters = List.from(_departmentFilters);
        // 부서 목록
        final departments = ['1청', '2청', '3청', '4청', '신혼부부'];

        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('부서 필터'),
              content: SizedBox(
                width: double.maxFinite,
                child: ListView(
                  shrinkWrap: true,
                  children: departments.map((department) {
                    return CheckboxListTile(
                      title: Text(department),
                      value: tempFilters.contains(department),
                      onChanged: (bool? value) {
                        setState(() {
                          if (value == true) {
                            tempFilters.add(department);
                          } else {
                            tempFilters.remove(department);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('취소'),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _departmentFilters = tempFilters;
                    });
                    // Main widget rebuild
                    this.setState(() {});
                    Navigator.pop(context);
                  },
                  child: const Text('적용'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('청년 관리'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(kToolbarHeight),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value;
                      });
                    },
                    decoration: const InputDecoration(
                      hintText: '이름 또는 전화번호 검색',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(vertical: 0),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.filter_list),
                  onPressed: _showFilterDialog,
                ),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    setState(() {
                      _sortOrder = value;
                    });
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: 'name', child: Text('이름순')),
                    const PopupMenuItem(value: 'classYear', child: Text('기수순')),
                    const PopupMenuItem(value: 'department', child: Text('소속순')),
                  ],
                  icon: const Icon(Icons.sort),
                ),
              ],
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _getUsersStream(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return const Center(child: Text('사용자 목록을 불러오는 중 오류가 발생했습니다.'));
            }

            final docs = snapshot.data?.docs ?? [];
            if (docs.isEmpty) {
              return const Center(child: Text('등록된 사용자가 없습니다.'));
            }

            final filteredAndSortedDocs = _filterAndSortUsers(docs);
            
            return ListView.separated(
              itemCount: filteredAndSortedDocs.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final doc = filteredAndSortedDocs[index];
                final data = doc.data();
                final name = (data['name'] ?? '이름 없음').toString();
                final phone = (data['phoneNumber'] ?? '').toString();
                final formattedPhone = formatPhoneNumber(phone);
                final birthDate = data['birthDate'] as String?;

                // 수정: AgeCalculator, DepartmentCalculator 사용
                final classYear = AgeCalculator.calculateClassYear(birthDate);
                final department = DepartmentCalculator.calculateDepartment(birthDate);

                return ListTile(
                  title: Text(name),
                  subtitle: Text('$department / ${classYear}기 / $formattedPhone'),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AdminUserProfileScreen(),
                        settings: RouteSettings(
                          arguments: AdminUserProfileArguments(
                            targetPhoneNumber: phone,
                            viewerPhoneNumber: widget.phoneNumber,
                            viewerPermissionLevel: widget.permissionLevel,
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }
}
