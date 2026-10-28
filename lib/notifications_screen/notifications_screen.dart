import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:video_player_app/utils/liquid_colors.dart';
import 'package:video_player_app/utils/notification_service.dart';
import 'package:video_player_app/views/screens/home_screen/widgets/liquid_animations/liquid_background.dart';
import 'package:video_player_app/widgets/app_empty_state.dart';
import 'package:video_player_app/widgets/app_spacing.dart';
import 'package:video_player_app/widgets/liquid_glass_surface.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      NotificationService.instance.markAllRead();
    });
  }

  Future<void> _confirmClearAll() async {
    final list = NotificationService.instance.notifications.value;
    if (list.isEmpty) return;
    HapticFeedback.lightImpact();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: LiquidGlassSurface(
            borderRadius: AppRadius.lg,
            blur: 24,
            padding: const EdgeInsets.all(22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Clear all notifications?',
                  style: TextStyle(
                    color: theme.colorScheme.onSurface,
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'This removes every notification. You can\'t undo this.',
                  style: TextStyle(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.68),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    _GlassTextButton(
                      label: 'Cancel',
                      onPressed: () => Navigator.pop(ctx, false),
                    ),
                    const SizedBox(width: 10),
                    _GlassTextButton(
                      label: 'Clear all',
                      tint: theme.colorScheme.error,
                      onPressed: () => Navigator.pop(ctx, true),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
    if (ok == true) {
      await NotificationService.instance.clearAll();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor.withValues(alpha: 0.78),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        systemOverlayStyle: LiquidColors.systemOverlayStyle,
        title: Text(
          'Notifications',
          style: TextStyle(
            color: LiquidColors.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          ValueListenableBuilder<List<AppNotification>>(
            valueListenable: NotificationService.instance.notifications,
            builder: (context, list, _) {
              if (list.isEmpty) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: _GlassTextButton(
                  label: 'Clear all',
                  tint: theme.colorScheme.error,
                  onPressed: _confirmClearAll,
                  compact: true,
                ),
              );
            },
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: LiquidBackground(
        neutral: true,
        child: ValueListenableBuilder<List<AppNotification>>(
          valueListenable: NotificationService.instance.notifications,
          builder: (context, list, _) {
            if (list.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: LiquidGlassSurface(
                    borderRadius: AppRadius.lg,
                    blur: 20,
                    padding: const EdgeInsets.all(24),
                    child: const AppEmptyState(
                      icon: Icons.notifications_none_rounded,
                      title: 'You\'re all caught up',
                      message:
                          'Update and new-feature alerts will appear here. Nothing '
                          'new right now.',
                    ),
                  ),
                ),
              );
            }
            return ListView.separated(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
              itemCount: list.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (_, i) => _NotificationTile(
                key: ValueKey(list[i].id),
                item: list[i],
                onDismiss: () =>
                    NotificationService.instance.remove(list[i].id),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final AppNotification item;
  final VoidCallback onDismiss;

  const _NotificationTile({
    super.key,
    required this.item,
    required this.onDismiss,
  });

  (IconData, Color) get _visual {
    switch (item.kind) {
      case 'security':
        return (Icons.gpp_maybe_rounded, LiquidColors.error);
      case 'update':
        return (Icons.system_update_alt_rounded, LiquidColors.indigo);
      case 'feature':
        return (Icons.auto_awesome_rounded, LiquidColors.indigo);
      default:
        return (Icons.notifications_rounded, LiquidColors.indigo);
    }
  }

  String get _relativeTime {
    final diff = DateTime.now().millisecondsSinceEpoch - item.timestamp;
    final mins = diff ~/ 60000;
    if (mins < 1) return 'Just now';
    if (mins < 60) return '${mins}m ago';
    final hrs = mins ~/ 60;
    if (hrs < 24) return '${hrs}h ago';
    final days = hrs ~/ 24;
    if (days < 7) return '${days}d ago';
    final weeks = days ~/ 7;
    return '${weeks}w ago';
  }

  @override
  Widget build(BuildContext context) {
    final (icon, color) = _visual;
    return Dismissible(
      key: ValueKey('dismiss_${item.id}'),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDismiss(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 22),
        decoration: BoxDecoration(
          color: LiquidColors.error.withValues(alpha: 0.16),
          borderRadius: AppRadius.rLg,
        ),
        child: Icon(Icons.delete_outline_rounded, color: LiquidColors.error),
      ),
      child: LiquidGlassSurface(
        borderRadius: AppRadius.lg,
        blur: 18,
        padding: const EdgeInsets.all(10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LiquidGlassSurface(
              borderRadius: 10,
              blur: 10,
              tintColor: color,
              tintOpacity: 0.12,
              child: SizedBox(
                width: 34,
                height: 34,
                child: Icon(icon, color: color, size: 18),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.title,
                          style: TextStyle(
                            color: LiquidColors.textPrimary,
                            fontSize: 14.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (!item.read) ...[
                        const SizedBox(width: 8),
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: LiquidColors.indigo,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    item.body,
                    style: TextStyle(
                      color: LiquidColors.textSecondary,
                      fontSize: 12.5,
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    _relativeTime,
                    style: TextStyle(
                      color: LiquidColors.textTertiary,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GlassTextButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  final Color? tint;
  final bool compact;

  const _GlassTextButton({
    required this.label,
    required this.onPressed,
    this.tint,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return LiquidGlassSurface(
      borderRadius: 12,
      blur: 12,
      tintColor: tint,
      tintOpacity: tint == null ? 0 : 0.12,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 12 : 16,
              vertical: compact ? 7 : 11,
            ),
            child: Text(
              label,
              style: TextStyle(
                color:
                    tint ?? theme.colorScheme.onSurface.withValues(alpha: 0.75),
                fontWeight: FontWeight.w700,
                fontSize: compact ? 12 : 13,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
