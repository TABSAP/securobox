import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:native_glass_navbar/native_glass_navbar.dart';

import 'package:video_player_app/utils/liquid_colors.dart';

class AppNav {
  AppNav._();
  static final ValueNotifier<int> tab = ValueNotifier<int>(0);
  static final ValueNotifier<bool> bottomBarVisible = ValueNotifier<bool>(true);

  /// Callback registered by MainScreen to handle tab selection.
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
    final neutral = theme.colorScheme.onSurface;
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.only(bottom: 4),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 5, 12, 4),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(30),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: Container(
                  height: 66,
                  decoration: BoxDecoration(
                    color: LiquidColors.surface.withValues(
                      alpha: LiquidColors.isDark ? 0.74 : 0.88,
                    ),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(
                      color: Colors.white.withValues(
                        alpha: LiquidColors.isDark ? 0.16 : 0.78,
                      ),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(
                          alpha: LiquidColors.isDark ? 0.18 : 0.07,
                        ),
                        blurRadius: 20,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(5),
                    child: LayoutBuilder(
                      builder: (context, constraints) => Stack(
                        children: [
                          AnimatedAlign(
                            alignment: current == 0
                                ? Alignment.centerLeft
                                : Alignment.centerRight,
                            duration: const Duration(milliseconds: 360),
                            curve: Curves.easeOutCubic,
                            child: SizedBox(
                              width: constraints.maxWidth / _navItems.length,
                              height: constraints.maxHeight,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(30),
                                  color: neutral.withValues(
                                    alpha: theme.brightness == Brightness.dark
                                        ? 0.16
                                        : 0.10,
                                  ),
                                  border: Border.all(
                                    color: neutral.withValues(
                                      alpha: theme.brightness == Brightness.dark
                                          ? 0.24
                                          : 0.18,
                                    ),
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: neutral.withValues(
                                        alpha:
                                            theme.brightness == Brightness.dark
                                            ? 0.08
                                            : 0.04,
                                      ),
                                      blurRadius: 12,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          Row(
                            children: List.generate(_navItems.length, (i) {
                              return Expanded(
                                child: _NavButton(
                                  item: _navItems[i],
                                  selected: i == current,
                                  showLabel: false,
                                  onTap: () => _onTap(i),
                                ),
                              );
                            }),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
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
