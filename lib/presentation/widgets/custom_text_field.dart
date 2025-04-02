import 'package:flutter/material.dart';

class CustomTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final bool obscureText;
  final TextInputType inputType;
  final ValueChanged<String>? onChanged;
  final Widget? suffixIcon;
  final String? Function(String?)? validator;
  final EdgeInsetsGeometry? contentPadding;
  final Color? borderColor;
  final Color? focusedBorderColor;
  final Color? hintColor;
  final Color? textColor;

  const CustomTextField({
    Key? key,
    required this.controller,
    required this.hint,
    this.obscureText = false,
    this.inputType = TextInputType.text,
    this.onChanged,
    this.suffixIcon,
    this.validator,
    this.contentPadding,
    this.borderColor,
    this.focusedBorderColor,
    this.hintColor,
    this.textColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: inputType,
      validator: validator ?? (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter $hint';
        }
        return null;
      },
      onChanged: onChanged,
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
        color: textColor ?? Colors.black,
      ),
      decoration: InputDecoration(
        suffixIcon: suffixIcon,
        hintText: hint,
        hintStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: hintColor ?? Colors.grey,
        ),
        contentPadding: contentPadding ?? const EdgeInsets.all(16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(
            color: borderColor ?? Colors.grey,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(
            color: focusedBorderColor ?? Colors.pinkAccent,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(
            color: borderColor ?? Colors.grey,
          ),
        ),
      ),
    );
  }
}
