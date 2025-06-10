import 'package:flutter/material.dart';

class CustomFloatingButton extends StatelessWidget {
  final VoidCallback onPressed;
  final String label;
  final IconData? icon;
  final Color backgroundColor;
  final Color labelColor;

  const CustomFloatingButton({
    super.key,
    required this.onPressed,
    this.label = "Reassign",
    this.icon,
    this.backgroundColor = const Color(0xFF1380FE),
    this.labelColor = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.extended(
      onPressed: onPressed,
      backgroundColor: backgroundColor,
      // shape: const CircleBorder(), // Circular shape
      label: Text(label, style: TextStyle(color: labelColor)),
    );
  }
}
