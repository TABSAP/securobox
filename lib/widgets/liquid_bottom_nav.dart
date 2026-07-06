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
    _NavItem(Icons.shield_moon_outlined, Icons.shield_moon_rounded, 'Logs'),
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
    return DecoratedBox(
      decoration: BoxDecoration(
          gradient: RadialGradient(
            colors: [
              LiquidColors.backgroundDeep,
              LiquidColors.backgroundMid,
              LiquidColors.backgroundLight,
            ],
            center: Alignment.center,
            radius: 1.2,
          ),
        color: LiquidColors.surface,
        border: Border(top: BorderSide(color: LiquidColors.cardBorder)),
        boxShadow: [
          BoxShadow(
            color: LiquidColors.shadow,
            blurRadius: 16,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 62,
          child: Row(
            children: List.generate(_navItems.length, (i) {
              return Expanded(
                child: _NavButton(
                  item: _navItems[i],
                  selected: i == current,
                  showBadge: i == 1,
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
    final accent = LiquidColors.accentBlue;
    final color = selected ? accent : LiquidColors.textTertiary;

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
                    border: Border.all(color: LiquidColors.surface, width: 1.5),
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
          AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            width: 58,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected
                  ? accent.withValues(alpha: 0.14)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(999),
            ),
            child: icon,
          ),
          const SizedBox(height: 4),
          AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 200),
            style: TextStyle(
              fontSize: 11.5,
              height: 1,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: color,
              letterSpacing: 0.1,
            ),
            child: Text(item.label),
          ),
        ],
      ),
    );
  }
}
