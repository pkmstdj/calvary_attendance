import 'dart:async';
import 'package:animated_notch_bottom_bar/animated_notch_bottom_bar/animated_notch_bottom_bar.dart';
import 'package:app_links/app_links.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../screens/attendance/nfc_check_in_screen.dart';
import '../../utils/team_utils.dart';
import '../admin/admin_root_screen.dart';
import '../leader/group_management_tab_screen.dart';
import '../teams/teams_root_screen.dart';
import 'home_tab_screen.dart';
import 'prayer_tab_screen.dart';
import 'profile_tab_screen.dart';
import 'sharing_tab_screen.dart';


// ScaleAnimatedIcon 위젯 정의
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
        vsync: this, duration: const Duration(milliseconds: 200));
    _scaleAnimation =
        Tween<double>(begin: 1.0, end: 1.2).animate(_animationController);
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

class MainRootScreen extends StatefulWidget {
  const MainRootScreen({super.key});

  @override
  State<MainRootScreen> createState() => _MainRootScreenState();
}

class _MainRootScreenState extends State<MainRootScreen> {
  final _pageController = PageController(initialPage: 0);
  late final NotchBottomBarController _controller;

  String? _phoneNumber;
  int _permissionLevel = 4;
  List<String> _userTags = [];
  bool _initialized = false;
  bool _isLoading = true;
  int _currentPageIndex = 0;

  late AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSubscription;

  @override
  void initState() {
    super.initState();
    _controller = NotchBottomBarController(index: 0);
    _initDeepLinks();
  }

  Future<void> _initDeepLinks() async {
    _appLinks = AppLinks();

    // Check initial link
    try {
      final initialLink = await _appLinks.getInitialAppLink();
      if (initialLink != null) {
        _handleDeepLink(initialLink);
      }
    } catch (e) {
      // Handle exception
    }

    // Listen for new links
    _linkSubscription = _appLinks.uriLinkStream.listen((uri) {
      _handleDeepLink(uri);
    });
  }

  void _handleDeepLink(Uri uri) {
    if (uri.scheme == 'calvary-app' && uri.host == 'check-in') {
      // 네비게이션이 가능한 상태인지 확인 후 이동
      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (context) => const NfcCheckInScreen()),
        );
      }
    }
  }

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
    _linkSubscription?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadUser() async {
    if (_phoneNumber == null) {
      if(mounted) setState(() => _isLoading = false);
      return;
    }
    try {
      final userQuery = await FirebaseFirestore.instance
          .collection('users')
          .where('phoneNumber', isEqualTo: _phoneNumber)
          .limit(1)
          .get();

      if (userQuery.docs.isEmpty) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      final userDoc = userQuery.docs.first;
      final data = userDoc.data();
      final userTags = (data.containsKey('tags') && data['tags'] is List)
          ? List<String>.from(data['tags'])
          : <String>[];

      if (mounted) {
        setState(() {
          _permissionLevel = (data['permissionLevel'] ?? 4) as int;
          _userTags = userTags;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
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

  void _openSpecialTeamsPage() {
    final tagsToShow = _permissionLevel == 0 ? TeamUtils.allTeams : _userTags;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (context) => TeamsRootScreen(
        userTags: tagsToShow,
      ),
    ));
  }

  List<Widget> _buildActions() {
    final actions = <Widget>[];

    final bool canSeeTeams = _permissionLevel == 0 || _userTags.isNotEmpty;
    if (canSeeTeams) {
      actions.add(
        IconButton(
          icon: const Icon(Icons.group_work_outlined),
          tooltip: '특별팀',
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
    if (_isLoading || _phoneNumber == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final List<Widget> pages = [];
    final List<BottomBarItem> bottomBarItems = [];

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final unselectedColor = theme.bottomNavigationBarTheme.unselectedItemColor;
    final selectedColor = colorScheme.onPrimary;

    // 1. 홈 (모두에게 보임)
    pages.add(HomeTabScreen(
      phoneNumber: _phoneNumber!,
      permissionLevel: _permissionLevel,
      isPending: _permissionLevel >= 4,
    ));
    bottomBarItems.add(BottomBarItem(
      inActiveItem: Icon(Icons.home, color: unselectedColor),
      activeItem: ScaleAnimatedIcon(icon: Icons.home, color: selectedColor),
    ));

    // 2. 리더(소그룹관리) 또는 청장/사역자(나눔) 탭
    if (_permissionLevel == 2) { // 리더
      pages.add(GroupManagementTabScreen(leaderPhoneNumber: _phoneNumber!));
      bottomBarItems.add(BottomBarItem(
        inActiveItem: Icon(Icons.groups, color: unselectedColor),
        activeItem: ScaleAnimatedIcon(icon: Icons.groups, color: selectedColor),
      ));
    } else if (_permissionLevel <= 1) { // 청장, 사역자
      pages.add(SharingTabScreen(
        currentUserPhoneNumber: _phoneNumber!,
        currentUserPermissionLevel: _permissionLevel,
      ));
      bottomBarItems.add(BottomBarItem(
        inActiveItem: Icon(Icons.share, color: unselectedColor),
        activeItem: ScaleAnimatedIcon(icon: Icons.share, color: selectedColor),
      ));
    }

    // 3. 기도제목 (수정: 등급 1, 2, 3 에게만 보임)
    if (_permissionLevel >= 1 && _permissionLevel <= 3) {
      pages.add(PrayerTabScreen(
        phoneNumber: _phoneNumber!,
        permissionLevel: _permissionLevel,
      ));
      bottomBarItems.add(BottomBarItem(
        inActiveItem: Icon(Icons.chat_bubble, color: unselectedColor),
        activeItem: ScaleAnimatedIcon(icon: Icons.chat_bubble, color: selectedColor),
      ));
    }

    // 4. 프로필 (모두에게 보임)
    pages.add(ProfileTabScreen(
      phoneNumber: _phoneNumber!,
    ));
    bottomBarItems.add(BottomBarItem(
      inActiveItem: Icon(Icons.person, color: unselectedColor),
      activeItem: ScaleAnimatedIcon(icon: Icons.person, color: selectedColor),
    ));


    return Scaffold(
      appBar: AppBar(
        title: const Text(''),
        actions: _buildActions(),
      ),
      body: PageView(
        controller: _pageController,
        onPageChanged: (index) {
          setState(() {
            _currentPageIndex = index;
          });
        },
        physics: const NeverScrollableScrollPhysics(),
        children: pages,
      ),
      extendBody: true,
      bottomNavigationBar: SafeArea(
        child: AnimatedNotchBottomBar(
          notchBottomBarController: _controller,
          onTap: (index) {
            if (index >= pages.length) return; // 안전장치
            setState(() {
              _currentPageIndex = index;
              _controller.index = index;
            });
            _pageController.jumpToPage(index);
          },
          color: Color.alphaBlend(Colors.black.withOpacity(0.04), theme.bottomNavigationBarTheme.backgroundColor ?? colorScheme.surface),
          notchColor: colorScheme.primary,
          kIconSize: 24,
          kBottomRadius: 28,
          showLabel: false,
          durationInMilliSeconds: 250,
          bottomBarItems: bottomBarItems,
        ),
      ),
    );
  }
}
