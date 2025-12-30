import 'package:animated_notch_bottom_bar/animated_notch_bottom_bar/animated_notch_bottom_bar.dart';
import 'package:flutter/material.dart';

import 'admin_admin_tab.dart';
import 'admin_main_tab.dart';
import 'admin_prayer_tab.dart';
import 'admin_student_tab.dart';
import '../user/main_root_screen.dart'; // For ScaleAnimatedIcon

class AdminRootArguments {
  final String phoneNumber;
  final int permissionLevel;

  AdminRootArguments({
    required this.phoneNumber,
    required this.permissionLevel,
  });
}

class AdminRootScreen extends StatefulWidget {
  const AdminRootScreen({super.key});

  @override
  State<AdminRootScreen> createState() => _AdminRootScreenState();
}

class _AdminRootScreenState extends State<AdminRootScreen> {
  final _pageController = PageController(initialPage: 0);
  final _controller = NotchBottomBarController(index: 0);

  late AdminRootArguments _args;
  bool _initialized = false;
  List<Widget> _tabs = [];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      final args = ModalRoute.of(context)!.settings.arguments;
      if (args is AdminRootArguments) {
        _args = args;
        _initialized = true;

        _tabs = [
          AdminMainTab(
            phoneNumber: _args.phoneNumber,
            permissionLevel: _args.permissionLevel,
          ),
          AdminStudentTab(
            phoneNumber: _args.phoneNumber,
            permissionLevel: _args.permissionLevel,
          ),
          AdminPrayerTab(
            phoneNumber: _args.phoneNumber,
            permissionLevel: _args.permissionLevel,
          ),
          if (_args.permissionLevel <= 1)
            AdminAdminTab(
              phoneNumber: _args.phoneNumber,
              permissionLevel: _args.permissionLevel,
            ),
        ];
      }
    }
  }

  @override
  void dispose() {
    // ThemeProvider 관련 코드 제거
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final bool isSuperAdmin = _args.permissionLevel <= 1;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(), // Prevent manual swipe
        children: _tabs,
      ),
      extendBody: true,
      bottomNavigationBar: SafeArea(
        child: AnimatedNotchBottomBar(
          notchBottomBarController: _controller,
          onTap: (index) {
            _pageController.animateToPage(index, duration: const Duration(milliseconds: 250), curve: Curves.ease);
          },
          color: Color.alphaBlend(Colors.black.withOpacity(0.04), theme.bottomNavigationBarTheme.backgroundColor ?? colorScheme.surface),
          notchColor: colorScheme.primary,
          kIconSize: 24,
          kBottomRadius: 28,
          showLabel: false,
          durationInMilliSeconds: 250,
          bottomBarItems: [
            BottomBarItem(inActiveItem: Icon(Icons.home, color: theme.bottomNavigationBarTheme.unselectedItemColor), activeItem: ScaleAnimatedIcon(icon: Icons.home, color: colorScheme.onPrimary)),
            BottomBarItem(inActiveItem: Icon(Icons.people, color: theme.bottomNavigationBarTheme.unselectedItemColor), activeItem: ScaleAnimatedIcon(icon: Icons.people, color: colorScheme.onPrimary)),
            BottomBarItem(inActiveItem: Icon(Icons.chat_bubble, color: theme.bottomNavigationBarTheme.unselectedItemColor), activeItem: ScaleAnimatedIcon(icon: Icons.chat_bubble, color: colorScheme.onPrimary)),
            if (isSuperAdmin)
              BottomBarItem(
                inActiveItem: Icon(Icons.admin_panel_settings, color: theme.bottomNavigationBarTheme.unselectedItemColor),
                activeItem: ScaleAnimatedIcon(icon: Icons.admin_panel_settings, color: colorScheme.onPrimary),
              ),
          ],
        ),
      ),
    );
  }
}
