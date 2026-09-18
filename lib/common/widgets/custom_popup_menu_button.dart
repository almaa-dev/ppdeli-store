import 'package:flutter/material.dart';
class CustomPopupMenuButton extends StatelessWidget {
  final Widget child;
  final List<MenuItem> items;
  final ValueChanged<int> onSelected;

  const CustomPopupMenuButton({
    super.key,
    required this.child,
    required this.items,
    required this.onSelected,
  });

  // Builds the custom content for each menu item
  PopupMenuItem<int> _buildPopupMenuItem(MenuItem item) {
    return PopupMenuItem<int>(
      value: item.value,
      // The key to customization: using a Row for the child property
      child: Row(
        children: [
          Text(item.title, style: const TextStyle(fontWeight: FontWeight.w500)),
          Spacer(),
          Icon(item.icon, color: item.color),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<int>(
      // 1. Anchor the menu to the custom button widget
      onSelected: onSelected,

      // 3. Customize the appearance of the entire menu container
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      elevation: 5.0,

      // 4. Customize the list of items
      itemBuilder: (BuildContext context) {
        return items.map((item) => _buildPopupMenuItem(item)).toList();
      },

      // 5. Customizing the position and overall look (optional, but highly customized)
      // This allows the menu to align cleanly below the button
      offset: const Offset(0, 30), // Moves the menu down so it starts below the button

      // Tooltip is optional but good practice
      tooltip: 'Show actions menu',
      // 1. Anchor the menu to the custom button widget
      child: child,
    );
  }
}

class MenuItem {
  final String title;
  final IconData? icon;
  final int value;
  final Color color;

  const MenuItem(this.title, this.icon, this.value, this.color);
}