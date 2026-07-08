import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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

  void _onTap(BuildContext context, int i) {
    HapticFeedback.selectionClick();
    AppNav.tab.value = i;
    final route = ModalRoute.of(context);
    if (route != null && !route.isFirst) {
      Navigator.of(context).popUntil((r) => r.isFirst);
    }
  }

  @override
  Widget build(BuildContext context) {
    final current = selectedIndex ?? 0;
    // Clean, flat navigation bar: theme-adaptive surface with a single hairline
    // divider on top — no pills or heavy shadows.
    return DecoratedBox(
      decoration: BoxDecoration(
        color: LiquidColors.backgroundDeep,
        border: Border(top: BorderSide(color: LiquidColors.divider)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 52,
          child: Row(
            children: List.generate(_navItems.length, (i) {
              return Expanded(
                child: _NavButton(
                  item: _navItems[i],
                  selected: i == current,
                  showBadge: false,
                  onTap: () => _onTap(context, i),
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

    Widget icon = Icon(
      selected ? item.activeIcon : item.icon,
      size: 22,
      color: color,
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
          const SizedBox(height: 3),
          Text(
            item.label,
            style: TextStyle(
              fontSize: 11,
              height: 1,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: color,
              letterSpacing: 0.1,
            ),
          ),
        ],
      ),
    );
  }
}
