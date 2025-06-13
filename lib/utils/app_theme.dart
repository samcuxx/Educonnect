import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Primary gradient colors for buttons and highlights
  static const Color lightPrimaryStart = Color(0xFF0bd1d1); // Cyan/Teal
  static const Color lightPrimaryEnd = Color(0xFF0ea5ea); // Blue

  static const Color darkPrimaryStart = Color(
    0xFF0bd1d1,
  ); // Same colors for dark mode
  static const Color darkPrimaryEnd = Color(
    0xFF0ea5ea,
  ); // for consistent branding

  // Secondary gradient colors
  static const Color lightSecondaryStart = Color(
    0xFF0bd1d1,
  ); // Using same gradient
  static const Color lightSecondaryEnd = Color(
    0xFF0ea5ea,
  ); // for secondary elements

  static const Color darkSecondaryStart = Color(
    0xFF0bd1d1,
  ); // Same in dark mode
  static const Color darkSecondaryEnd = Color(0xFF0ea5ea); // for consistency

  // Background colors
  static const Color lightBackground = Colors.white; // White
  static const Color darkBackground = Color(0xFF0f172a); // Dark blue

  // Surface/Foreground colors
  static const Color lightSurface = Colors.white; // Solid white for light mode
  static const Color darkSurface = Color(0xFF091c31); // Very dark blue

  // Surface variant colors
  static const Color lightSurfaceVariant = Color(0xFFF5F5F5); // Light gray
  static const Color darkSurfaceVariant = Color(0xFF1a2942); // Darker blue

  // Input fill colors
  static const Color lightInputFill = Color(0xFFF8F8F8); // Very light gray
  static const Color darkInputFill = Color(0xFF132236); // Dark blue-gray

  // Text colors
  static const Color lightTextPrimary = Color(0xFF222222); // Dark gray
  static const Color darkTextPrimary = Color(0xFF94a9c9); // Light blue-gray

  static const Color lightTextSecondary = Color(
    0xFF222222,
  ); // Same as primary for now
  static const Color darkTextSecondary = Color(
    0xFF94a9c9,
  ); // Same as primary for now

  // Tertiary text colors
  static const Color lightTextTertiary = Color(0xFF666666); // Medium gray
  static const Color darkTextTertiary = Color(0xFF718096); // Medium blue-gray

  // Border colors
  static const Color lightBorder = Color(0xFFe5e5e5); // Light gray
  static const Color darkBorder = Color(0xFF222f43); // Dark blue-gray

  // Create linear gradients for various UI elements
  static LinearGradient primaryGradient(bool isDark) {
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [lightPrimaryStart, lightPrimaryEnd], // Same for both modes
    );
  }

  static LinearGradient secondaryGradient(bool isDark) {
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [lightSecondaryStart, lightSecondaryEnd], // Same for both modes
    );
  }

  // Base text theme with Inter font
  static TextTheme _createBaseTextTheme(
    Color primaryColor,
    Color secondaryColor,
  ) {
    return TextTheme(
      displayLarge: GoogleFonts.inter(
        color: primaryColor,
        fontWeight: FontWeight.w700,
      ),
      displayMedium: GoogleFonts.inter(
        color: primaryColor,
        fontWeight: FontWeight.w700,
      ),
      displaySmall: GoogleFonts.inter(
        color: primaryColor,
        fontWeight: FontWeight.w700,
      ),
      headlineLarge: GoogleFonts.inter(
        color: primaryColor,
        fontWeight: FontWeight.w700,
      ),
      headlineMedium: GoogleFonts.inter(
        color: primaryColor,
        fontWeight: FontWeight.w700,
      ),
      headlineSmall: GoogleFonts.inter(
        color: primaryColor,
        fontWeight: FontWeight.w700,
      ),
      titleLarge: GoogleFonts.inter(
        color: primaryColor,
        fontWeight: FontWeight.w600,
      ),
      titleMedium: GoogleFonts.inter(
        color: primaryColor,
        fontWeight: FontWeight.w600,
      ),
      titleSmall: GoogleFonts.inter(
        color: primaryColor,
        fontWeight: FontWeight.w600,
      ),
      bodyLarge: GoogleFonts.inter(
        color: primaryColor,
        fontWeight: FontWeight.w400,
      ),
      bodyMedium: GoogleFonts.inter(
        color: secondaryColor,
        fontWeight: FontWeight.w400,
      ),
      bodySmall: GoogleFonts.inter(
        color: secondaryColor,
        fontWeight: FontWeight.w400,
      ),
      labelLarge: GoogleFonts.inter(
        color: primaryColor,
        fontWeight: FontWeight.w500,
      ),
      labelMedium: GoogleFonts.inter(
        color: primaryColor,
        fontWeight: FontWeight.w500,
      ),
      labelSmall: GoogleFonts.inter(
        color: secondaryColor,
        fontWeight: FontWeight.w500,
      ),
    );
  }

  // Light theme
  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: ColorScheme.light(
      primary: lightPrimaryStart,
      secondary: lightSecondaryStart,
      surface: lightSurface,
      background: lightBackground,
      onBackground: lightTextPrimary,
      onSurface: lightTextPrimary,
      outline: lightBorder,
    ),
    scaffoldBackgroundColor: lightBackground,
    fontFamily: GoogleFonts.inter().fontFamily,
    appBarTheme: AppBarTheme(
      backgroundColor: lightBackground,
      foregroundColor: lightTextPrimary,
      elevation: 0,
      titleTextStyle: GoogleFonts.inter(
        color: lightTextPrimary,
        fontWeight: FontWeight.w600,
        fontSize: 18,
      ),
    ),
    dividerColor: lightBorder,
    textTheme: _createBaseTextTheme(lightTextPrimary, lightTextSecondary),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        foregroundColor: Colors.white,
        backgroundColor: lightPrimaryStart,
        textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: lightPrimaryStart,
        textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: lightPrimaryStart,
        textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600),
        side: BorderSide(color: lightPrimaryStart),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      hintStyle: GoogleFonts.inter(color: lightTextSecondary.withOpacity(0.7)),
      labelStyle: GoogleFonts.inter(color: lightTextSecondary),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(28),
        borderSide: BorderSide(color: lightBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(28),
        borderSide: BorderSide(color: lightBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(28),
        borderSide: BorderSide(color: lightPrimaryStart, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(28),
        borderSide: BorderSide(color: lightSecondaryStart),
      ),
    ),
  );

  // Dark theme
  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: ColorScheme.dark(
      primary: darkPrimaryStart,
      secondary: darkSecondaryStart,
      surface: darkSurface,
      background: darkBackground,
      onBackground: darkTextPrimary,
      onSurface: darkTextPrimary,
      outline: darkBorder,
    ),
    scaffoldBackgroundColor: darkBackground,
    fontFamily: GoogleFonts.inter().fontFamily,
    appBarTheme: AppBarTheme(
      backgroundColor: darkBackground,
      foregroundColor: darkTextPrimary,
      elevation: 0,
      titleTextStyle: GoogleFonts.inter(
        color: darkTextPrimary,
        fontWeight: FontWeight.w600,
        fontSize: 18,
      ),
    ),
    dividerColor: darkBorder,
    textTheme: _createBaseTextTheme(darkTextPrimary, darkTextSecondary),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        foregroundColor: Colors.white,
        backgroundColor: darkPrimaryStart,
        textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: darkPrimaryStart,
        textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: darkPrimaryStart,
        textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600),
        side: BorderSide(color: darkPrimaryStart),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: darkSurface,
      hintStyle: GoogleFonts.inter(color: darkTextSecondary.withOpacity(0.7)),
      labelStyle: GoogleFonts.inter(color: darkTextSecondary),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(28),
        borderSide: BorderSide(color: darkBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(28),
        borderSide: BorderSide(color: darkBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(28),
        borderSide: BorderSide(color: darkPrimaryStart, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(28),
        borderSide: BorderSide(color: darkSecondaryStart),
      ),
    ),
  );
}
