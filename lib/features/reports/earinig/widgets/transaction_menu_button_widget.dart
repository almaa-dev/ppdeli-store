import 'package:flutter/material.dart';
import 'package:ppdelistore/util/dimensions.dart';

class TransactionsMenuButton extends StatelessWidget {
  final String label;
  final int count;
  final bool isSelected;
  final VoidCallback onTap;

  const TransactionsMenuButton({
    super.key,
    required this.label,
    required this.count,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = isSelected
        ? Theme.of(context).primaryColor
        : Theme.of(context).hintColor.withAlpha(50);
    final labelColor = isSelected
        ? Theme.of(context).scaffoldBackgroundColor
        : Theme.of(context).hintColor;
    final badgeBg = isSelected
        ? Theme.of(context).scaffoldBackgroundColor.withAlpha(50)
        : Colors.white;
    final badgeText = isSelected ? Colors.white : Theme.of(context).hintColor;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: labelColor,
              ),
            ),
            const SizedBox(width: 8),
            // Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
              decoration: BoxDecoration(
                color: badgeBg,
                borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: badgeText,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
