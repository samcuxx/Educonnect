import 'package:flutter/material.dart';

class AppTheme {
  // Primary gradient colors
  static const Color lightPrimaryStart = Color(0xFF3366FF);
  static const Color lightPrimaryEnd = Color(0xFF00CCFF);
  
  static const Color darkPrimaryStart = Color(0xFF3700B3);
  static const Color darkPrimaryEnd = Color(0xFF6200EE);
  
  // Secondary gradient colors
  static const Color lightSecondaryStart = Color.fromARGB(255, 44, 80, 65);  // Deep blue-gray
  static const Color lightSecondaryEnd = Color.fromARGB(255, 106, 194, 154);    // Darker blue-gray
  
  static const Color darkSecondaryStart = Color.fromARGB(255, 44, 80, 65);   // Deep blue-gray
  static const Color darkSecondaryEnd = Color.fromARGB(255, 106, 194, 154);     // Darker blue-gray
  
  // Background colors
  static const Color lightBackground = Color(0xFFF7F9FC);
  static const Color darkBackground = Color(0xFF121212);
  
  // Surface colors
  static const Color lightSurface = Colors.white;
  static const Color darkSurface = Color(0xFF1E1E1E);
  
  // Text colors
  static const Color lightTextPrimary = Color(0xFF2A2D3E);
  static const Color darkTextPrimary = Color(0xFFF5F5F5);
  
  static const Color lightTextSecondary = Color(0xFF6C7693);
  static const Color darkTextSecondary = Color(0xFFB0B0B0);
  
  // Create linear gradients for various UI elements
  static LinearGradient primaryGradient(bool isDark) {
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: isDark
          ? [darkPrimaryStart, darkPrimaryEnd]
          : [lightPrimaryStart, lightPrimaryEnd],
    );
  }
  
  static LinearGradient secondaryGradient(bool isDark) {
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: isDark
          ? [darkSecondaryStart, darkSecondaryEnd]
          : [lightSecondaryStart, lightSecondaryEnd],
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
    ),
    scaffoldBackgroundColor: lightBackground,
    appBarTheme: AppBarTheme(
      backgroundColor: lightSurface,
      foregroundColor: lightTextPrimary,
      elevation: 0,
    ),
    textTheme: TextTheme(
      headlineLarge: TextStyle(color: lightTextPrimary, fontWeight: FontWeight.bold),
      headlineMedium: TextStyle(color: lightTextPrimary, fontWeight: FontWeight.bold),
      headlineSmall: TextStyle(color: lightTextPrimary, fontWeight: FontWeight.bold),
      titleLarge: TextStyle(color: lightTextPrimary),
      titleMedium: TextStyle(color: lightTextPrimary),
      bodyLarge: TextStyle(color: lightTextPrimary),
      bodyMedium: TextStyle(color: lightTextSecondary),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        foregroundColor: Colors.white,
        backgroundColor: lightPrimaryStart,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: lightPrimaryStart),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
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
    ),
    scaffoldBackgroundColor: darkBackground,
    appBarTheme: AppBarTheme(
      backgroundColor: darkSurface,
      foregroundColor: darkTextPrimary,
      elevation: 0,
    ),
    textTheme: TextTheme(
      headlineLarge: TextStyle(color: darkTextPrimary, fontWeight: FontWeight.bold),
      headlineMedium: TextStyle(color: darkTextPrimary, fontWeight: FontWeight.bold),
      headlineSmall: TextStyle(color: darkTextPrimary, fontWeight: FontWeight.bold),
      titleLarge: TextStyle(color: darkTextPrimary),
      titleMedium: TextStyle(color: darkTextPrimary),
      bodyLarge: TextStyle(color: darkTextPrimary),
      bodyMedium: TextStyle(color: darkTextSecondary),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        foregroundColor: Colors.white,
        backgroundColor: darkPrimaryStart,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Color(0xFF2A2D3E),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.grey.shade800),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.grey.shade800),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: darkPrimaryStart),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: darkSecondaryStart),
      ),
    ),
  );
} 