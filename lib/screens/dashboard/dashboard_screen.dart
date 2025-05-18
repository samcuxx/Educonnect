import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import '../../providers/auth_provider.dart';
import '../../utils/app_theme.dart';
import 'home_tab.dart';
import 'classes_tab.dart';
import 'resources_tab.dart';
import 'profile_tab.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  final PageController _pageController = PageController();
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeIn,
      ),
    );

    // Start the animation when the widget is built
    _animationController.forward();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _onTabTapped(int index) {
    if (index == _currentIndex) return;
    
    // Start page transition animation
    _animationController.reset();
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
    
    setState(() {
      _currentIndex = index;
    });
    
    // Start fade-in animation for the new page content
    _animationController.forward();
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
                colors: isDark
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
              FadeTransition(
                opacity: _fadeAnimation,
                child: const HomeTab(),
              ),
              
              // Classes tab - Shows all classes
              FadeTransition(
                opacity: _fadeAnimation,
                child: const ClassesTab(),
              ),
              
              // Resources tab - Shows all resources
              FadeTransition(
                opacity: _fadeAnimation,
                child: const ResourcesTab(),
              ),
              
              // Profile tab - Shows user profile
              FadeTransition(
                opacity: _fadeAnimation,
                child: const ProfileTab(),
              ),
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
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
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
                  icon: Icons.class_rounded, 
                  label: 'Classes', 
                  index: 1,
                  isDark: isDark,
                ),
                _buildTabItem(
                  context: context, 
                  icon: Icons.book_rounded, 
                  label: 'Resources', 
                  index: 2,
                  isDark: isDark,
                ),
                _buildTabItem(
                  context: context, 
                  icon: Icons.person_rounded, 
                  label: 'Profile', 
                  index: 3,
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
    final selectedGradient = isLecturer
        ? AppTheme.secondaryGradient(isDark)
        : AppTheme.primaryGradient(isDark);
    
    final selectedColor = isLecturer
        ? (isDark ? AppTheme.darkSecondaryStart : AppTheme.lightSecondaryStart)
        : (isDark ? AppTheme.darkPrimaryStart : AppTheme.lightPrimaryStart);
    
    final unselectedColor = isDark 
        ? AppTheme.darkTextSecondary 
        : AppTheme.lightTextSecondary;
    
    return InkWell(
      onTap: () => _onTabTapped(index),
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        decoration: BoxDecoration(
          gradient: isSelected ? selectedGradient : null,
          color: isSelected
              ? null
              : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.white : unselectedColor,
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
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