import 'package:flutter/material.dart';

import '../../../../utils/liquid_colors.dart';
import 'package:video_player_app/widgets/app_empty_state.dart';

class LiquidDeletedEmptyState extends StatelessWidget {
  final bool hasSearch;
  final VoidCallback onBackPressed;

  const LiquidDeletedEmptyState({
    super.key,
    required this.hasSearch,
    required this.onBackPressed,
  });

  @override
  Widget build(BuildContext context) {
    return AppEmptyState(
      icon: hasSearch ? Icons.search_off_rounded : Icons.delete_outline_rounded,
      title: hasSearch ? 'No deleted files found' : 'Trash is empty',
      message: hasSearch
          ? 'Try a different search term'
          : 'Deleted files will appear here',
      actionLabel: 'Back to Library',
      onAction: onBackPressed,
      accent: hasSearch ? LiquidColors.error : LiquidColors.accentBlue,
    );
  }
}
