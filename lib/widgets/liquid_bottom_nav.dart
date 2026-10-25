import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:native_glass_navbar/native_glass_navbar.dart';

import 'package:video_player_app/utils/intrusion_service.dart';
import 'package:video_player_app/utils/liquid_colors.dart';

class AppNav {
  AppNav._();
  static final ValueNotifier<int> tab = ValueNotifier<int>(0);
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
    HapticFeedback.selectionClick();
    AppNav.tab.value = i;
  }

  @override
  Widget build(BuildContext context) {
    final current = selectedIndex ?? 0;
    final fallback = _buildPremiumFallback(context, current);
    if (defaultTargetPlatform != TargetPlatform.iOS) return fallback;

    return NativeGlassNavBar(
      currentIndex: current,
      onTap: _onTap,
      tintColor: LiquidColors.indigo,
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
      // The plugin automatically uses this on iOS versions without Liquid
      // Glass. Keeping it custom also gives the app a polished Android bar.
      fallback: fallback,
    );
  }

  Widget _buildPremiumFallback(BuildContext context, int current) {
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.only(bottom: 5),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(27),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              height: 66,
              decoration: BoxDecoration(
                color: LiquidColors.surface.withValues(
                  alpha: LiquidColors.isDark ? 0.82 : 0.88,
                ),
                borderRadius: BorderRadius.circular(27),
                border: Border.all(
                  color: LiquidColors.cardBorder.withValues(alpha: 0.9),
                ),
                boxShadow: [
                  BoxShadow(
                    color: LiquidColors.shadow,
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                children: List.generate(_navItems.length, (i) {
                  return Expanded(
                    child: _NavButton(
                      item: _navItems[i],
                      selected: i == current,
                      showBadge: false,
                      onTap: () => _onTap(i),
                    ),
                  );
                }),
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
  final bool showBadge;
  final VoidCallback onTap;

  const _NavButton({
    required this.item,
    required this.selected,
    required this.showBadge,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Selected uses the single brand indigo; unselected uses an adaptive
    // secondary colour (dark in light theme, light in dark theme).
    final color = selected ? LiquidColors.indigo : LiquidColors.textSecondary;

    Widget icon = AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
      decoration: BoxDecoration(
        color: selected
            ? LiquidColors.indigo.withValues(
                alpha: LiquidColors.isDark ? 0.2 : 0.1,
              )
            : Colors.transparent,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Icon(
        selected ? item.activeIcon : item.icon,
        size: 21,
        color: color,
      ),
    );
    if (showBadge) {
      icon = Stack(
        clipBehavior: Clip.none,
        children: [
          icon,
          Positioned(
            right: -8,
            top: -5,
            child: ValueListenableBuilder<int>(
              valueListenable: IntrusionService.instance.logCount,
              builder: (context, count, _) {
                if (count <= 0) return const SizedBox.shrink();
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 1,
                  ),
                  constraints: const BoxConstraints(minWidth: 15),
                  decoration: BoxDecoration(
                    color: LiquidColors.error,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: LiquidColors.backgroundDeep,
                      width: 1.5,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    count > 99 ? '99+' : '$count',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 8.5,
                      fontWeight: FontWeight.w800,
                      height: 1.2,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      );
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          icon,
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
      ),
    );
  }
}
