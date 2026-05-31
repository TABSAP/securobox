import 'package:flutter/widgets.dart';

/// Width at or above which the device is treated as a tablet / large screen.
const double kTabletBreakpoint = 600;

/// Width at or above which an extra grid column is worthwhile.
const double kWideBreakpoint = 900;

extension Responsive on BuildContext {
  double get screenWidth => MediaQuery.sizeOf(this).width;

  bool get isTablet => screenWidth >= kTabletBreakpoint;

  bool get isWide => screenWidth >= kWideBreakpoint;

  /// Picks a value by form factor without scattering MediaQuery checks.
  T responsive<T>({required T phone, required T tablet, T? wide}) {
    if (isWide && wide != null) return wide;
    return isTablet ? tablet : phone;
  }

  /// Symmetric horizontal padding that keeps [phone] spacing on small screens
  /// but, on tablets, grows so the content column is centred and capped near
  /// [maxContent] wide instead of stretching edge-to-edge.
  double contentInset({double maxContent = 680, double phone = 16}) {
    final w = screenWidth;
    if (w < kTabletBreakpoint) return phone;
    final inset = (w - maxContent) / 2;
    return inset > phone ? inset : phone;
  }
}

/// Centres its [child] and caps it at [maxWidth] on tablets so content stops
/// stretching edge-to-edge on large screens. On phones it is a no-op pass
/// through, preserving the existing full-width layout.
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
