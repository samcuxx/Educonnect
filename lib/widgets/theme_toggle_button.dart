import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../utils/app_theme.dart';

class ThemeToggleButton extends StatelessWidget {
  const ThemeToggleButton({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;
    final size = 32.0;

    IconData getThemeIcon() {
      switch (themeProvider.themeMode) {
        case ThemeMode.light:
          return Icons.light_mode;
        case ThemeMode.dark:
          return Icons.dark_mode;
        case ThemeMode.system:
          return Icons.brightness_auto;
      }
    }

    return Container(
      height: size,
      width: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: AppTheme.primaryGradient(isDark),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? AppTheme.darkPrimaryStart.withOpacity(0.3)
                : AppTheme.lightPrimaryStart.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: IconButton(
        padding: EdgeInsets.zero,
        iconSize: size - 8,
        color: Colors.white,
        icon: Icon(getThemeIcon()),
        onPressed: () {
          // Cycle through theme modes: system -> light -> dark -> system
          switch (themeProvider.themeMode) {
            case ThemeMode.system:
              themeProvider.setThemeMode(ThemeMode.light);
              break;
            case ThemeMode.light:
              themeProvider.setThemeMode(ThemeMode.dark);
              break;
            case ThemeMode.dark:
              themeProvider.setThemeMode(ThemeMode.system);
              break;
          }
        },
      ),
    );
  }
} 