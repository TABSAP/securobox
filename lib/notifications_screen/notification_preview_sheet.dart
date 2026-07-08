import 'package:flutter/material.dart';

import 'package:video_player_app/notifications_screen/notifications_screen.dart';
import 'package:video_player_app/utils/liquid_colors.dart';
import 'package:video_player_app/utils/notification_service.dart';
import 'package:video_player_app/widgets/app_spacing.dart';

/// A compact modal bottom-sheet preview of the latest notifications, opened
/// from the bell icon. Shows up to 5 newest notifications and a "View All"
/// action that pushes the full [NotificationsScreen].
class NotificationPreviewSheet extends StatefulWidget {
  const NotificationPreviewSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const NotificationPreviewSheet(),
    );
  }

  @override
  State<NotificationPreviewSheet> createState() =>
      _NotificationPreviewSheetState();
}

class _NotificationPreviewSheetState extends State<NotificationPreviewSheet> {
  @override
  void initState() {
    super.initState();
    // Opening the sheet marks everything as read (clears the bell badge).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      NotificationService.instance.markAllRead();
    });
  }

  void _openAll() {
    final navigator = Navigator.of(context);
    navigator.pop();
    navigator.push(
      MaterialPageRoute(builder: (_) => const NotificationsScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.of(context).size.height * 0.70;
    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      decoration: BoxDecoration(
        color: LiquidColors.backgroundLight,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: LiquidColors.cardBorder),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Grab handle.
            Padding(
              padding: const EdgeInsets.only(top: 10, bottom: 6),
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: LiquidColors.textTertiary.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            // Header.
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 6, 20, 12),
              child: Row(
                children: [
                  Text(
                    'Notifications',
                    style: TextStyle(
                      color: LiquidColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            Flexible(
              child: ValueListenableBuilder<List<AppNotification>>(
                valueListenable: NotificationService.instance.notifications,
                builder: (context, list, _) {
                  if (list.isEmpty) {
                    return _buildEmpty();
                  }
                  final items = list.take(5).toList();
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: ListView.separated(
                          shrinkWrap: true,
                          physics: const BouncingScrollPhysics(),
                          padding:
                              const EdgeInsets.fromLTRB(16, 0, 16, 12),
                          itemCount: items.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 8),
                          itemBuilder: (_, i) =>
                              _CompactNotificationCard(item: items[i]),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                        child: SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: _openAll,
                            style: FilledButton.styleFrom(
                              backgroundColor: LiquidColors.indigo,
                              foregroundColor: Colors.white,
                              padding:
                                  const EdgeInsets.symmetric(vertical: 14),
                              shape: const RoundedRectangleBorder(
                                borderRadius: AppRadius.rMd,
                              ),
                            ),
                            child: const Text(
                              'View All',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 44),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: LiquidColors.textPrimary.withValues(alpha: 0.06),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.notifications_none_rounded,
              color: LiquidColors.textSecondary,
              size: 30,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'You\'re all caught up',
            style: TextStyle(
              color: LiquidColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'New updates and alerts will show up here.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: LiquidColors.textTertiary,
              fontSize: 13,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _CompactNotificationCard extends StatelessWidget {
  final AppNotification item;

  const _CompactNotificationCard({required this.item});

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
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: LiquidColors.backgroundLight.withValues(alpha: 0.55),
        borderRadius: AppRadius.rMd,
        border: Border.all(color: LiquidColors.cardBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: LiquidColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  item.body,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: LiquidColors.textSecondary,
                    fontSize: 12.5,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  _relativeTime,
                  style: TextStyle(
                    color: LiquidColors.textTertiary,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
