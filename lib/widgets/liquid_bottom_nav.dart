import 'dart:math' as math;

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

class LiquidBottomNav extends StatefulWidget {
  final int? selectedIndex;

  const LiquidBottomNav({super.key, this.selectedIndex});

  @override
  State<LiquidBottomNav> createState() => _LiquidBottomNavState();
}

class _LiquidBottomNavState extends State<LiquidBottomNav>
    with SingleTickerProviderStateMixin {
  static const List<_NavItem> _navItems = [
    _NavItem(
      Icons.video_library_outlined,
      Icons.video_library_rounded,
      'Library',
    ),
    _NavItem(
      Icons.shield_moon_outlined,
      Icons.shield_moon_rounded,
      'Intrusions',
    ),
    _NavItem(Icons.settings_outlined, Icons.settings_rounded, 'Settings'),
  ];

  static const double _barHeight = 56;
  static const double _blobW = 58;
  static const double _blobH = 42;

  late final AnimationController _slide = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 460),
    value: 1,
  );
  late int _prev = widget.selectedIndex ?? -1;
  late int _curr = widget.selectedIndex ?? -1;
  int? _pressed;

  @override
  void didUpdateWidget(covariant LiquidBottomNav old) {
    super.didUpdateWidget(old);
    final next = widget.selectedIndex ?? -1;
    if (next != _curr) {
      _prev = _curr;
      _curr = next;
      _slide.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _slide.dispose();
    super.dispose();
  }

  double _lerp(double a, double b, double t) => a + (b - a) * t;

  void _onTap(int i) {
    HapticFeedback.selectionClick();
    AppNav.tab.value = i;
    final route = ModalRoute.of(context);
    if (route != null && !route.isFirst) {
      Navigator.of(context).popUntil((r) => r.isFirst);
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = LiquidColors.accentBlue;
    return Container(
      decoration: BoxDecoration(
        color: LiquidColors.surface.withValues(alpha: 0.97),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(26),
          topRight: Radius.circular(26),
        ),
        border: Border(top: BorderSide(color: LiquidColors.cardBorder)),
        boxShadow: [
          BoxShadow(
            color: LiquidColors.shadow,
            blurRadius: 22,
            spreadRadius: 1,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
          child: SizedBox(
            height: _barHeight,
            child: LayoutBuilder(
              builder: (context, c) {
                final n = _navItems.length;
                final cell = c.maxWidth / n;
                double leftFor(int i) => i * cell + (cell - _blobW) / 2;

                return AnimatedBuilder(
                  animation: _slide,
                  builder: (context, _) {
                    final t = Curves.easeOutCubic.transform(_slide.value);
                    final wave = math.sin(_slide.value * math.pi);
                    final bw = _blobW * (1 + wave * 0.5);
                    final bh = _blobH * (1 - wave * 0.18);
                    final from = _prev >= 0 ? _prev : _curr;
                    final blobLeft = _curr >= 0
                        ? _lerp(leftFor(from), leftFor(_curr), t)
                        : 0.0;

                    return Stack(
                      clipBehavior: Clip.none,
                      children: [
                        if (_curr >= 0)
                          Positioned(
                            left: blobLeft - (bw - _blobW) / 2,
                            top: (_barHeight - bh) / 2,
                            width: bw,
                            height: bh,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(bh / 2),
                                gradient: RadialGradient(
                                  colors: [
                                    accent.withValues(alpha: 0.32),
                                    accent.withValues(alpha: 0.10),
                                  ],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: accent.withValues(alpha: 0.30),
                                    blurRadius: 22,
                                    spreadRadius: -2,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        Row(
                          children: List.generate(n, (i) {
                            final double sel;
                            if (i == _curr) {
                              sel = _prev == _curr ? 1.0 : t;
                            } else if (i == _prev) {
                              sel = 1.0 - t;
                            } else {
                              sel = 0.0;
                            }
                            final pressed = _pressed == i;
                            final iconScale =
                                _lerp(0.9, 1.12, sel) * (pressed ? 0.86 : 1.0);
                            final color = Color.lerp(
                              LiquidColors.textTertiary,
                              accent,
                              sel,
                            )!;
                            final item = _navItems[i];
                            Widget iconWidget = Transform.scale(
                              scale: iconScale,
                              child: Icon(
                                sel > 0.5 ? item.activeIcon : item.icon,
                                color: color,
                                size: 23,
                              ),
                            );
                            if (i == 1) {
                              iconWidget = Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  iconWidget,
                                  Positioned(
                                    right: -9,
                                    top: -6,
                                    child: ValueListenableBuilder<int>(
                                      valueListenable:
                                          IntrusionService.instance.logCount,
                                      builder: (context, count, _) {
                                        if (count <= 0) {
                                          return const SizedBox.shrink();
                                        }
                                        return Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 4,
                                            vertical: 1,
                                          ),
                                          constraints: const BoxConstraints(
                                            minWidth: 16,
                                          ),
                                          decoration: BoxDecoration(
                                            color: LiquidColors.error,
                                            borderRadius:
                                                BorderRadius.circular(999),
                                            border: Border.all(
                                              color: LiquidColors.surface,
                                              width: 1.5,
                                            ),
                                          ),
                                          alignment: Alignment.center,
                                          child: Text(
                                            count > 99 ? '99+' : '$count',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 9,
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
                            return Expanded(
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTapDown: (_) => setState(() => _pressed = i),
                                onTapCancel: () =>
                                    setState(() => _pressed = null),
                                onTapUp: (_) => setState(() => _pressed = null),
                                onTap: () => _onTap(i),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    iconWidget,
                                    const SizedBox(height: 3),
                                    Text(
                                      item.label,
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        height: 1.1,
                                        fontWeight: sel > 0.5
                                            ? FontWeight.w700
                                            : FontWeight.w500,
                                        color: color,
                                        letterSpacing: 0.1,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
