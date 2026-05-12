import 'package:flutter/material.dart';

import '../../utils/liquid_colors.dart';

class LiquidCategorySelector extends StatefulWidget {
  final String selectedCategory;
  final Function(String) onCategoryChanged;
  final List<String> categories;
  final IconData Function(String) getIcon;
  final Color Function(String) getColor;

  const LiquidCategorySelector({
    super.key,
    required this.selectedCategory,
    required this.onCategoryChanged,
    required this.categories,
    required this.getIcon,
    required this.getColor,
  });

  @override
  State<LiquidCategorySelector> createState() => _LiquidCategorySelectorState();
}

class _LiquidCategorySelectorState extends State<LiquidCategorySelector>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _pulseAnimation.value,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  LiquidColors.backgroundLight.withValues(alpha: 0.9),
                  LiquidColors.backgroundMid.withValues(alpha: 0.95),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: widget.getColor(widget.selectedCategory).withValues(alpha: 0.3),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: widget.getColor(widget.selectedCategory).withValues(alpha: 0.2),
                  blurRadius: 15,
                  spreadRadius: 0,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Icon(
                  widget.getIcon(widget.selectedCategory),
                  color: widget.getColor(widget.selectedCategory),
                  size: 22,
                ),
                const SizedBox(width: 12),
                Text(
                  'Category:',
                  style: TextStyle(
                    color: LiquidColors.textSecondary,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButton<String>(
                    value: widget.selectedCategory,
                    isExpanded: true,
                    dropdownColor: LiquidColors.backgroundLight,
                    style: TextStyle(
                      color: LiquidColors.textPrimary,
                      fontSize: 14,
                    ),
                    underline: const SizedBox(),
                    icon: Icon(
                      Icons.arrow_drop_down_rounded,
                      color: widget.getColor(widget.selectedCategory),
                    ),
                    items: widget.categories
                        .map((category) => DropdownMenuItem(
                      value: category,
                      child: Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: widget.getColor(category),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            category,
                            style: TextStyle(color: LiquidColors.textPrimary),
                          ),
                        ],
                      ),
                    ))
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        widget.onCategoryChanged(value);
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
