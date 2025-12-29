import 'package:animated_notch_bottom_bar/animated_notch_bottom_bar/animated_notch_bottom_bar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../admin/admin_root_screen.dart';
import '../leader/group_management_tab_screen.dart'; // 소그룹 관리 화면 import
import '../teams/special_teams_screen.dart';
import 'home_tab_screen.dart';
import 'prayer_tab_screen.dart';
import 'profile_tab_screen.dart';
import 'sharing_tab_screen.dart';

class MainRootScreen extends StatefulWidget {
  const MainRootScreen({super.key});

  @override
  State<MainRootScreen> createState() => _MainRootScreenState();
}

class _MainRootScreenState extends State<MainRootScreen> {
  final _pageController = PageController(initialPage: 0);
  final _controller = NotchBottomBarController(index: 0);

  String? _phoneNumber;
  int _permissionLevel = 4;
  List<String> _userTags = [];
  bool _hasSpecialTeamTag = false; // 특별팀 태그 소유 여부
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      final modalRoute = ModalRoute.of(context);
      if (modalRoute != null) {
        final args = modalRoute.settings.arguments;
        if (args is String) {
          _phoneNumber = args;
          _loadUser();
        }
      }
      _initialized = true;
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadUser() async {
    if (_phoneNumber == null) return;
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(_phoneNumber)
          .get();
      if (!userDoc.exists) return;

      final data = userDoc.data();
      if (data == null) return;

      // 사용자의 태그 목록 가져오기
      final userTags = (data.containsKey('tags') && data['tags'] is List)
          ? List<String>.from(data['tags'])
          : <String>[];

      // '특별팀'으로 지정된 모든 태그 이름 가져오기
      final specialTagsQuery = await FirebaseFirestore.instance
          .collection('tags')
          .where('isSpecialTeam', isEqualTo: true)
          .get();
      final specialTeamNames =
          specialTagsQuery.docs.map((doc) => doc.data()['name'] as String).toSet();

      // 사용자가 특별팀 태그를 가지고 있는지 확인
      final userTagSet = userTags.toSet();
      final hasTag = userTagSet.intersection(specialTeamNames).isNotEmpty;

      if (mounted) {
        setState(() {
          _permissionLevel = (data['permissionLevel'] ?? 4) as int;
          _userTags = userTags;
          _hasSpecialTeamTag = hasTag;
        });
      }
    } catch (_) {
      // 에러는 조용히 무시
    }
  }

  void _openAdminPage() {
    if (_phoneNumber == null) return;
    if (_permissionLevel > 2) return;

    Navigator.pushNamed(
      context,
      '/adminRoot',
      arguments: AdminRootArguments(
        phoneNumber: _phoneNumber!,
        permissionLevel: _permissionLevel,
      ),
    );
  }

  // SpecialTeamsScreen으로 이동 시 사용자 정보 전달
  void _openSpecialTeamsPage() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (context) => SpecialTeamsScreen(
        userTags: _userTags,
        permissionLevel: _permissionLevel,
      ),
    ));
  }

  List<Widget> _buildActions() {
    final actions = <Widget>[];

    // 권한 레벨 0 또는 특별팀 태그가 있는 경우 아이콘 표시
    final bool hasSpecialRole = _permissionLevel == 0 || _hasSpecialTeamTag;

    if (hasSpecialRole) {
      actions.add(
        IconButton(
          icon: const Icon(Icons.groups),
          onPressed: _openSpecialTeamsPage,
        ),
      );
    }

    if (_permissionLevel <= 2) {
      actions.add(
        IconButton(
          icon: const Icon(Icons.admin_panel_settings),
          onPressed: _openAdminPage,
        ),
      );
    }

    return actions;
  }

  @override
  Widget build(BuildContext context) {
    if (_phoneNumber == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // 권한에 따라 페이지 목록 구성
    final List<Widget> pages = [
      HomeTabScreen(
        phoneNumber: _phoneNumber!,
        permissionLevel: _permissionLevel,
        isPending: _permissionLevel >= 4,
      ),
      // 권한 레벨 3 (리더)는 소그룹 관리 탭 표시
      if (_permissionLevel == 3)
        GroupManagementTabScreen(leaderPhoneNumber: _phoneNumber!),
      // 권한 레벨 2 이하 (관리자)는 함께 기도 탭 표시
      if (_permissionLevel <= 2)
        SharingTabScreen(
          currentUserPhoneNumber: _phoneNumber!,
          currentUserPermissionLevel: _permissionLevel,
        ),
      // 권한 레벨 3 이하는 기도 탭 표시
      if (_permissionLevel <= 3)
        PrayerTabScreen(
          phoneNumber: _phoneNumber!,
          permissionLevel: _permissionLevel,
        ),
      ProfileTabScreen(
        phoneNumber: _phoneNumber!,
      ),
    ];

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('갈보리청년'),
        actions: _buildActions(),
      ),
      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(), // Prevent manual swipe
        children: pages,
      ),
      extendBody: true,
      bottomNavigationBar: SafeArea(
        child: AnimatedNotchBottomBar(
          notchBottomBarController: _controller,
          onTap: (index) {
            _pageController.animateToPage(index,
                duration: const Duration(milliseconds: 250),
                curve: Curves.ease);
          },
          color: Color.alphaBlend(Colors.black.withOpacity(0.04),
              theme.bottomNavigationBarTheme.backgroundColor ?? colorScheme.surface),
          notchColor: colorScheme.primary,
          kIconSize: 24,
          kBottomRadius: 28,
          showLabel: false,
          durationInMilliSeconds: 250,
          bottomBarItems: [
            BottomBarItem(
                inActiveItem: Icon(Icons.home,
                    color: theme.bottomNavigationBarTheme.unselectedItemColor),
                activeItem: ScaleAnimatedIcon(
                    icon: Icons.home, color: colorScheme.onPrimary)),
            // 권한 3 (리더)는 그룹 아이콘
            if (_permissionLevel == 3)
              BottomBarItem(
                  inActiveItem: Icon(Icons.group,
                      color:
                          theme.bottomNavigationBarTheme.unselectedItemColor),
                  activeItem: ScaleAnimatedIcon(
                      icon: Icons.group, color: colorScheme.onPrimary)),
            // 권한 2 이하 (관리자)는 기존 아이콘
            if (_permissionLevel <= 2)
              BottomBarItem(
                  inActiveItem: Icon(Icons.question_answer,
                      color:
                          theme.bottomNavigationBarTheme.unselectedItemColor),
                  activeItem: ScaleAnimatedIcon(
                      icon: Icons.question_answer,
                      color: colorScheme.onPrimary)),
            // 권한 3 이하는 기도 탭 아이콘
            if (_permissionLevel <= 3)
              BottomBarItem(
                  inActiveItem: Icon(Icons.chat_bubble,
                      color:
                          theme.bottomNavigationBarTheme.unselectedItemColor),
                  activeItem: ScaleAnimatedIcon(
                      icon: Icons.chat_bubble, color: colorScheme.onPrimary)),
            BottomBarItem(
                inActiveItem: Icon(Icons.person,
                    color: theme.bottomNavigationBarTheme.unselectedItemColor),
                activeItem: ScaleAnimatedIcon(
                    icon: Icons.person, color: colorScheme.onPrimary)),
          ],
        ),
      ),
    );
  }
}

class ScaleAnimatedIcon extends StatefulWidget {
  final IconData icon;
  final Color color;

  const ScaleAnimatedIcon({super.key, required this.icon, required this.color});

  @override
  State<ScaleAnimatedIcon> createState() => _ScaleAnimatedIconState();
}

class _ScaleAnimatedIconState extends State<ScaleAnimatedIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );

    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween<double>(begin: 0.5, end: 1.2), weight: 60),
      TweenSequenceItem(tween: Tween<double>(begin: 1.2, end: 1.0), weight: 40),
    ]).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: Icon(widget.icon, color: widget.color),
    );
  }
}
