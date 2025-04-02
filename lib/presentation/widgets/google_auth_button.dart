import 'package:flutter/material.dart';

class GoogleAuthButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  final Color borderColor;
  final Color textColor;
  final double borderRadius;
  final EdgeInsetsGeometry padding;
  final double elevation;
  final double iconSize;
  final TextStyle? textStyle;

  const GoogleAuthButton({
    Key? key,
    required this.label,
    required this.onPressed,
    this.borderColor = Colors.black,
    this.textColor = Colors.black,
    this.borderRadius = 16.0,
    this.padding = const EdgeInsets.symmetric(vertical: 16.0),
    this.elevation = 0,
    this.iconSize = 24.0,
    this.textStyle,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        elevation: elevation,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(borderRadius),
        ),
        side: BorderSide(width: 1.0, color: borderColor),
        padding: padding,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset(
            'assets/images/google_icon.png',
            width: iconSize,
            height: iconSize,
          ),
          const SizedBox(width: 10),
          Text(
            label,
            style: textStyle ?? TextStyle(
              fontSize: 18.0,
              color: textColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
