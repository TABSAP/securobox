import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:native_glass_navbar/native_glass_navbar.dart';

import 'package:video_player_app/utils/liquid_colors.dart';

class AppNav {
  AppNav._();
  static final ValueNotifier<int> tab = ValueNotifier<int>(0);
  static final ValueNotifier<bool> bottomBarVisible = ValueNotifier<bool>(true);

  static void Function(int index)? onTabSelected;

  static void selectTab(int index) {
    final handler = onTabSelected;
    if (handler != null) {
      handler(index);
    } else {
      tab.value = index;
    }
  }
}

class _NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  const _NavItem(this.icon, this.activeIcon, this.label);
}

class LiquidBottomNav extends StatelessWidget {
  final int? selectedIndex;

  const LiquidBottomNav({super.key, this.selectedIndex});

  static const List<_NavItem> _navItems = [
    _NavItem(
      Icons.video_library_outlined,
      Icons.video_library_rounded,
      'Library',
    ),
    _NavItem(Icons.settings_outlined, Icons.settings_rounded, 'Settings'),
  ];

  void _onTap(int i) {
    if (i < 0 || i >= _navItems.length) return;
    AppNav.selectTab(i);
  }

  @override
  Widget build(BuildContext context) {
    final current = selectedIndex ?? 0;
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      final tint = Theme.of(context).colorScheme.onSurface;
      return NativeGlassNavBar(
        key: const ValueKey('securobox-native-glass-nav'),
        currentIndex: current,
        onTap: _onTap,
        tintColor: tint,
        tabs: const [
          NativeGlassNavBarItem(
            label: 'Library',
            symbol: 'rectangle.stack',
            selectedSymbol: 'rectangle.stack.fill',
          ),
          NativeGlassNavBarItem(
            label: 'Settings',
            symbol: 'gearshape',
            selectedSymbol: 'gearshape.fill',
          ),
        ],
        fallback: _buildPremiumFallback(context, current),
      );
    }
    return _buildPremiumFallback(context, current);
  }

  Widget _buildPremiumFallback(BuildContext context, int current) {
    final theme = Theme.of(context);
    return SafeArea(
      top: false,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: LiquidColors.surface,
          border: Border(
            top: BorderSide(color: theme.dividerColor, width: 0.7),
          ),
        ),
        child: SizedBox(
          height: 64,
          child: Row(
            children: List.generate(_navItems.length, (i) {
              return Expanded(
                child: _NavButton(
                  item: _navItems[i],
                  selected: i == current,
                  showLabel: true,
                  onTap: () => _onTap(i),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  final _NavItem item;
  final bool selected;
  final bool showLabel;
  final VoidCallback onTap;

  const _NavButton({
    required this.item,
    required this.selected,
    required this.showLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected
        ? Theme.of(context).colorScheme.onSurface
        : LiquidColors.textSecondary;

    Widget icon = AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      switchInCurve: Curves.easeOutBack,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (child, animation) =>
          ScaleTransition(scale: animation, child: child),
      child: Icon(
        selected ? item.activeIcon : item.icon,
        key: ValueKey(selected),
        size: 25,
        color: color,
      ),
    );
    return Semantics(
      button: true,
      selected: selected,
      label: item.label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(22),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              icon,
              if (showLabel) ...[
                const SizedBox(height: 2),
                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 180),
                  style: TextStyle(
                    fontSize: 10.5,
                    height: 1,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: color,
                    letterSpacing: 0.15,
                  ),
                  child: Text(item.label),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
