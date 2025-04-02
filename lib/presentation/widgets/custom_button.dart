import 'package:flutter/material.dart';

class CustomButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  final Color color;
  final Color textColor;
  final double borderRadius;
  final EdgeInsetsGeometry padding;
  final double elevation;

  const CustomButton({
    Key? key,
    required this.label,
    required this.onPressed,
    required this.color,
    this.textColor = Colors.white,
    this.borderRadius = 16.0,
    this.padding = const EdgeInsets.symmetric(vertical: 16.0),
    this.elevation = 0,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        elevation: elevation,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(borderRadius),
        ),
        backgroundColor: color,
        padding: padding,
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: textColor,
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }
}
