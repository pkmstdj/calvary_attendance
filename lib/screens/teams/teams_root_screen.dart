import 'package:flutter/material.dart';

import '../../utils/team_utils.dart';
import 'choir_team_tab.dart';
import 'education_team_tab.dart';
import 'executive_team_tab.dart';
import 'guidance_support_team_tab.dart';
import 'media_team_tab.dart';
import 'missions_team_tab.dart';
import 'new_family_team_tab.dart';
import 'praise_team_tab.dart';
import 'worship_team_tab.dart';

/// 사용자가 소유한 태그(팀)에 따라 동적으로 탭을 표시하는 화면
class TeamsRootScreen extends StatefulWidget {
  final List<String> userTags;

  const TeamsRootScreen({super.key, required this.userTags});

  @override
  State<TeamsRootScreen> createState() => _TeamsRootScreenState();
}

class _TeamsRootScreenState extends State<TeamsRootScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late List<Widget> _tabs;
  late List<Widget> _tabViews;

  @override
  void initState() {
    super.initState();

    _tabs = [];
    _tabViews = [];

    // 사용자의 태그와 일치하는 팀 탭만 동적으로 구성
    for (String teamName in TeamUtils.allTeams) {
      if (widget.userTags.contains(teamName)) {
        _tabs.add(Tab(text: teamName));
        _tabViews.add(_getTeamScreen(teamName));
      }
    }

    _tabController = TabController(length: _tabs.length, vsync: this);
  }

  Widget _getTeamScreen(String teamName) {
    switch (teamName) {
      case '임원':
        return const ExecutiveTeamTab();
      case '안내&지원팀':
        return const GuidanceSupportTeamTab();
      case '선교팀':
        return const MissionsTeamTab();
      case '교육훈련팀':
        return const EducationTeamTab();
      case '찬양팀':
        return const PraiseTeamTab();
      case '성가대':
        return const ChoirTeamTab();
      case '워십팀':
        return const WorshipTeamTab();
      case '새가족팀':
        return const NewFamilyTeamTab();
      case '미디어팀':
        return const MediaTeamTab();
      default:
        return Center(child: Text('$teamName 화면을 찾을 수 없습니다.'));
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('사역팀'),
        bottom: _tabs.isNotEmpty
            ? TabBar(
                controller: _tabController,
                tabs: _tabs,
                isScrollable: true,
              )
            : null,
      ),
      body: _tabs.isNotEmpty
          ? TabBarView(
              controller: _tabController,
              children: _tabViews,
            )
          : const Center(
              child: Text('소속된 사역팀이 없습니다.'),
            ),
    );
  }
}
