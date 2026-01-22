import 'package:flutter/material.dart';
import 'package:video_player_app/upload_screen/upload_screen.dart';
import 'video_library_screen/video_library_screen.dart';
import 'download_screen/download_screen.dart';
import 'security_settings/security_setting.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  // 🔥 GLOBAL KEY
  final _libraryKey = GlobalKey<VideoLibraryScreenState>();

  void _onVideoUploaded() {
    // 1️⃣ switch to library tab
    setState(() {
      _selectedIndex = 0;
    });

    // 2️⃣ force refresh library
    _libraryKey.currentState?.refreshVideos();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A1F),
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          // ✅ SAME screen instance – but refreshable
          VideoLibraryScreen(key: _libraryKey),
          UploadScreen(
            onVideoUploaded: _onVideoUploaded,
          ),
          const DownloadScreen(),
          const SecuritySettingsScreen(),
        ],
      ),
      bottomNavigationBar: _ProfessionalNavigationBar(
        selectedIndex: _selectedIndex,
        onTabSelected: (index) {
          setState(() => _selectedIndex = index);
        },
      ),
    );
  }
}

class _ProfessionalNavigationBar extends StatefulWidget {
  final int selectedIndex;
  final ValueChanged<int> onTabSelected;

  const _ProfessionalNavigationBar({
    required this.selectedIndex,
    required this.onTabSelected,
  });

  @override
  State<_ProfessionalNavigationBar> createState() =>
      _ProfessionalNavigationBarState();
}

class _ProfessionalNavigationBarState extends State<_ProfessionalNavigationBar> {
  // Navigation items configuration
  static const List<NavigationItem> _navItems = [
    NavigationItem(
      icon: Icons.video_library_outlined,
      activeIcon: Icons.video_library_rounded,
      label: 'Library',
    ),
    NavigationItem(
      icon: Icons.cloud_upload_outlined,
      activeIcon: Icons.cloud_upload_rounded,
      label: 'Upload',
    ),
    NavigationItem(
      icon: Icons.download_outlined,
      activeIcon: Icons.download_rounded,
      label: 'Downloads',
    ),
    NavigationItem(
      icon: Icons.security_outlined,
      activeIcon: Icons.security_rounded,
      label: 'Security',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF141432).withOpacity(0.95),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 20,
            spreadRadius: 2,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 12,
      ),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: List.generate(_navItems.length, (index) {
            final item = _navItems[index];
            final isSelected = widget.selectedIndex == index;

            return _NavigationButton(
              item: item,
              isSelected: isSelected,
              onTap: () => widget.onTabSelected(index),
            );
          }),
        ),
      ),
    );
  }
}

class _NavigationButton extends StatelessWidget {
  final NavigationItem item;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavigationButton({
    required this.item,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 10,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: isSelected
              ? const Color(0xFF4788FF).withOpacity(0.15)
              : Colors.transparent,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Animated icon
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (child, animation) {
                return ScaleTransition(
                  scale: animation,
                  child: child,
                );
              },
              child: Icon(
                isSelected ? item.activeIcon : item.icon,
                key: ValueKey(isSelected ? 'active_${item.label}' : item.label),
                color: isSelected
                    ? const Color(0xFF4788FF)
                    : Colors.grey.withOpacity(0.7),
                size: 24,
              ),
            ),
            const SizedBox(height: 4),
            // Animated label
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              transform: Matrix4.identity()
                ..scale(isSelected ? 1.0 : 0.9, isSelected ? 1.0 : 0.9),
              child: Text(
                item.label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected
                      ? const Color(0xFF4788FF)
                      : Colors.grey.withOpacity(0.7),
                  letterSpacing: -0.2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class NavigationItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;

  const NavigationItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
}