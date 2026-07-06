import 'package:flutter/material.dart';

import 'package:video_player_app/widgets/app_empty_state.dart';

class LiquidEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String buttonText;
  final VoidCallback onButtonPressed;
  final Color iconColor;

  const LiquidEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.buttonText,
    required this.onButtonPressed,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return AppEmptyState(
      icon: icon,
      title: title,
      message: subtitle,
      actionLabel: buttonText,
      onAction: onButtonPressed,
      accent: iconColor,
    );
  }
}
