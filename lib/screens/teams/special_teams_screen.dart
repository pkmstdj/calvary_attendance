import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class SpecialTeamsScreen extends StatefulWidget {
  final List<String> userTags;
  final int permissionLevel;

  const SpecialTeamsScreen({
    super.key,
    required this.userTags,
    required this.permissionLevel,
  });

  @override
  State<SpecialTeamsScreen> createState() => _SpecialTeamsScreenState();
}

class _SpecialTeamsScreenState extends State<SpecialTeamsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<String> _tabs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTabs();
  }

  Future<void> _loadTabs() async {
    try {
      final tagsQuery = await FirebaseFirestore.instance
          .collection('tags')
          .where('isSpecialTeam', isEqualTo: true)
          .get();

      final allSpecialTeams =
          tagsQuery.docs.map((doc) => doc.data()['name'] as String).toList();

      List<String> visibleTabs;

      // 권한 레벨 0은 모든 특별팀 탭을 볼 수 있음
      if (widget.permissionLevel == 0) {
        visibleTabs = allSpecialTeams;
      } else {
        // 그 외 사용자는 자신이 속한 특별팀 탭만 볼 수 있음
        final userTagSet = widget.userTags.toSet();
        visibleTabs = allSpecialTeams
            .where((team) => userTagSet.contains(team))
            .toList();
      }

      if (mounted) {
        setState(() {
          _tabs = visibleTabs;
          _isLoading = false;
          _tabController = TabController(length: _tabs.length, vsync: this);
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
      // 에러 처리 (예: 스낵바 표시)
    }
  }

  @override
  void dispose() {
    if (_tabs.isNotEmpty) {
      _tabController.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final appBarForegroundColor =
        theme.appBarTheme.foregroundColor ?? colorScheme.onPrimary;

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('특별팀')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_tabs.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('특별팀')),
        body: const Center(child: Text('표시할 특별팀이 없습니다.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('특별팀'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: appBarForegroundColor,
          unselectedLabelColor: appBarForegroundColor.withOpacity(0.7),
          indicatorColor: appBarForegroundColor,
          isScrollable: _tabs.length > 3, // 탭이 많으면 스크롤 가능하도록 설정
          tabs: _tabs.map((tabName) => Tab(text: tabName)).toList(),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: _tabs
            .map((tabName) => Center(child: Text('$tabName 페이지')))
            .toList(),
      ),
    );
  }
}
