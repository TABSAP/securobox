import 'package:flutter/material.dart';
import '../../../../utils/liquid_colors.dart';

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
    return Center(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TweenAnimationBuilder(
              tween: Tween<double>(begin: 0, end: 1),
              duration: const Duration(milliseconds: 800),
              curve: Curves.elasticOut,
              builder: (context, double value, child) {
                return Transform.scale(
                  scale: value,
                  child: Container(
                    width: 140,
                    height: 140,
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        colors: [
                          LiquidColors.error.withOpacity(0.2),
                          LiquidColors.backgroundLight.withOpacity(0.1),
                        ],
                        center: Alignment.center,
                        radius: 0.8,
                      ),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(
                        color: LiquidColors.error.withOpacity(0.3),
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: LiquidColors.error.withOpacity(0.2),
                          blurRadius: 30,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: Center(
                      child: Icon(
                        hasSearch ? Icons.search_off_rounded : Icons.delete_outline_rounded,
                        size: 60,
                        color: LiquidColors.error,
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 24),
            Text(
              hasSearch ? 'No Deleted Files Found' : 'Trash is Empty',
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              hasSearch
                  ? 'Try a different search term'
                  : 'Deleted files will appear here',
              style: TextStyle(
                color: Colors.grey.shade400,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 24),
            TweenAnimationBuilder(
              tween: Tween<double>(begin: 0, end: 1),
              duration: const Duration(milliseconds: 600),
              curve: Curves.elasticOut,
              builder: (context, double value, child) {
                return Transform.scale(
                  scale: value,
                  child: ElevatedButton.icon(
                    onPressed: onBackPressed,
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('Back to Library'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: LiquidColors.accentBlue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      elevation: 8,
                      shadowColor: LiquidColors.accentBlue.withOpacity(0.4),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}