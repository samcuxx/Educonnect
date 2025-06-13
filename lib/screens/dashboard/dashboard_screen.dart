import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import '../../providers/auth_provider.dart';
import '../../providers/student_management_provider.dart';
import '../../utils/app_theme.dart';
import 'home_tab.dart';
import 'classes_tab.dart';
import 'resources_tab.dart';
import 'profile_tab.dart';
import '../lecturer/students_tab.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _currentIndex = 0;
  final PageController _pageController = PageController();
  // Store route arguments to pass to tabs
  Map<String, dynamic>? _routeArguments;

  @override
  void initState() {
    super.initState();

    // Delay to allow build to complete before checking arguments
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkForTabIndexArgument();
    });
  }

  void _checkForTabIndexArgument() {
    final args = ModalRoute.of(context)?.settings.arguments;

    if (args != null && args is Map<String, dynamic>) {
      // Store arguments to pass to tabs
      _routeArguments = args;

      final tabIndex = args['tabIndex'];
      if (tabIndex != null && tabIndex is int && tabIndex != _currentIndex) {
        _onTabTapped(tabIndex);
      }
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onTabTapped(int index) {
    if (index == _currentIndex) return;

    _pageController.jumpToPage(index);

    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final authProvider = Provider.of<AuthProvider>(context);
    final isLecturer = authProvider.isLecturer;

    // Set system UI overlay style based on theme
    SystemChrome.setSystemUIOverlayStyle(
      isDark
          ? SystemUiOverlayStyle.light.copyWith(
            statusBarColor: Colors.transparent,
            systemNavigationBarColor: AppTheme.darkSurface,
            systemNavigationBarIconBrightness: Brightness.light,
          )
          : SystemUiOverlayStyle.dark.copyWith(
            statusBarColor: Colors.transparent,
            systemNavigationBarColor: AppTheme.lightSurface,
            systemNavigationBarIconBrightness: Brightness.dark,
          ),
    );

    return Scaffold(
      body: Stack(
        children: [
          // Gradient background
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors:
                    isDark
                        ? [
                          AppTheme.darkBackground,
                          AppTheme.darkBackground.withOpacity(0.8),
                        ]
                        : [
                          AppTheme.lightPrimaryStart.withOpacity(0.05),
                          AppTheme.lightPrimaryEnd.withOpacity(0.02),
                        ],
              ),
            ),
          ),

          // Page content
          PageView(
            controller: _pageController,
            physics: const NeverScrollableScrollPhysics(), // Disable swiping
            children: [
              // Home tab - Shows overview
              const HomeTab(),

              // Classes tab - Shows all classes
              const ClassesTab(),

              // Resources tab - Shows all resources
              ResourcesTab(routeArguments: _routeArguments),

              // Students tab - Only for lecturers
              if (isLecturer)
                ChangeNotifierProvider(
                  create:
                      (context) => StudentManagementProvider(
                        Provider.of<AuthProvider>(
                          context,
                          listen: false,
                        ).supabaseService,
                      ),
                  child: const StudentsTab(),
                ),

              // Profile tab - Shows user profile
              const ProfileTab(),
            ],
          ),
        ],
      ),

      // Bottom navigation bar with tabs
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 6.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildTabItem(
                  context: context,
                  icon: Icons.home_rounded,
                  label: 'Home',
                  index: 0,
                  isDark: isDark,
                ),
                _buildTabItem(
                  context: context,
                  icon: Icons.school_rounded,
                  label: 'Classes',
                  index: 1,
                  isDark: isDark,
                ),
                _buildTabItem(
                  context: context,
                  icon: Icons.folder_rounded,
                  label: 'Resources',
                  index: 2,
                  isDark: isDark,
                ),
                if (isLecturer)
                  _buildTabItem(
                    context: context,
                    icon: Icons.people_rounded,
                    label: 'Students',
                    index: 3,
                    isDark: isDark,
                  ),
                _buildTabItem(
                  context: context,
                  icon: Icons.person_rounded,
                  label: 'Profile',
                  index: isLecturer ? 4 : 3,
                  isDark: isDark,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTabItem({
    required BuildContext context,
    required IconData icon,
    required String label,
    required int index,
    required bool isDark,
  }) {
    final isSelected = _currentIndex == index;
    final isLecturer = Provider.of<AuthProvider>(context).isLecturer;

    // Use secondary colors for lecturers, primary colors for students
    final selectedGradient =
        isLecturer
            ? AppTheme.secondaryGradient(isDark)
            : AppTheme.primaryGradient(isDark);

    final selectedColor =
        isLecturer
            ? (isDark
                ? AppTheme.darkSecondaryStart
                : AppTheme.lightSecondaryStart)
            : (isDark ? AppTheme.darkPrimaryStart : AppTheme.lightPrimaryStart);

    final unselectedColor =
        isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary;

    return InkWell(
      onTap: () => _onTabTapped(index),
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
        decoration: BoxDecoration(
          gradient: isSelected ? selectedGradient : null,
          color: isSelected ? null : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.white : unselectedColor,
              size: 22,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? Colors.white : unselectedColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
