import 'package:flutter/material.dart';
import '../utils/app_theme.dart';

class CustomTextField extends StatelessWidget {
  final TextEditingController controller;
  final String labelText;
  final String? hintText;
  final bool obscureText;
  final TextInputType keyboardType;
  final String? Function(String?)? validator;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final bool enabled;
  final void Function(String)? onChanged;

  const CustomTextField({
    Key? key,
    required this.controller,
    required this.labelText,
    this.hintText,
    this.obscureText = false,
    this.keyboardType = TextInputType.text,
    this.validator,
    this.prefixIcon,
    this.suffixIcon,
    this.enabled = true,
    this.onChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor =
        isDark ? AppTheme.darkPrimaryStart : AppTheme.lightPrimaryStart;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextFormField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        validator: validator,
        enabled: enabled,
        onChanged: onChanged,
        style: TextStyle(
          fontWeight: FontWeight.w400,
          color:
              enabled
                  ? (isDark ? Colors.white : Colors.black)
                  : (isDark ? Colors.white60 : Colors.black45),
        ),
        decoration: InputDecoration(
          labelText: labelText,
          hintText: hintText,
          prefixIcon:
              prefixIcon != null
                  ? Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: prefixIcon,
                  )
                  : null,
          suffixIcon: suffixIcon,
          filled: true,
          fillColor:
              enabled
                  ? (isDark ? Colors.white.withOpacity(0.1) : Colors.white)
                  : (isDark
                      ? Colors.white.withOpacity(0.05)
                      : Colors.grey[100]),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(28.0),
            borderSide: BorderSide(
              color:
                  isDark
                      ? Colors.grey.shade800.withOpacity(0.3)
                      : Colors.grey.shade300.withOpacity(0.5),
              width: 0.8,
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(28.0),
            borderSide: BorderSide(
              color:
                  isDark
                      ? Colors.grey.shade800.withOpacity(0.3)
                      : Colors.grey.shade300.withOpacity(0.5),
              width: 0.8,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(28.0),
            borderSide: BorderSide(
              color: primaryColor.withOpacity(0.7),
              width: 1.2,
            ),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(28.0),
            borderSide: BorderSide(
              color:
                  isDark
                      ? AppTheme.darkSecondaryStart.withOpacity(0.6)
                      : AppTheme.lightSecondaryStart.withOpacity(0.6),
              width: 0.8,
            ),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(28.0),
            borderSide: BorderSide(
              color:
                  isDark
                      ? AppTheme.darkSecondaryStart.withOpacity(0.7)
                      : AppTheme.lightSecondaryStart.withOpacity(0.7),
              width: 1.2,
            ),
          ),
          contentPadding: const EdgeInsets.symmetric(
            vertical: 16.0,
            horizontal: 22.0,
          ),
          labelStyle: TextStyle(
            color:
                isDark
                    ? AppTheme.darkTextSecondary.withOpacity(0.8)
                    : AppTheme.lightTextSecondary.withOpacity(0.8),
            fontWeight: FontWeight.w400,
          ),
          hintStyle: TextStyle(
            color:
                isDark
                    ? AppTheme.darkTextSecondary.withOpacity(0.5)
                    : AppTheme.lightTextSecondary.withOpacity(0.5),
            fontWeight: FontWeight.w300,
          ),
          disabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(28.0),
            borderSide: BorderSide(
              color: isDark ? Colors.white12 : Colors.black12,
            ),
          ),
        ),
      ),
    );
  }
}
