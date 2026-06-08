import 'package:flutter/widgets.dart';

const double kTabletBreakpoint = 600;

const double kWideBreakpoint = 900;

extension Responsive on BuildContext {
  double get screenWidth => MediaQuery.sizeOf(this).width;

  bool get isTablet => screenWidth >= kTabletBreakpoint;

  bool get isWide => screenWidth >= kWideBreakpoint;

  T responsive<T>({required T phone, required T tablet, T? wide}) {
    if (isWide && wide != null) return wide;
    return isTablet ? tablet : phone;
  }

  double contentInset({double maxContent = 680, double phone = 16}) {
    final w = screenWidth;
    if (w < kTabletBreakpoint) return phone;
    final inset = (w - maxContent) / 2;
    return inset > phone ? inset : phone;
  }
}

class ResponsiveCenter extends StatelessWidget {
  const ResponsiveCenter({
    super.key,
    required this.child,
    this.maxWidth = 700,
  });

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    if (context.screenWidth < kTabletBreakpoint) return child;
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}
