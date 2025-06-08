import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/class_provider.dart';
import '../../providers/theme_provider.dart';
import '../../utils/app_theme.dart';
import '../../widgets/gradient_container.dart';
import '../../widgets/gradient_button.dart';
import '../../models/user_model.dart';
import '../profile/edit_profile_screen.dart';

class ProfileTab extends StatefulWidget {
  const ProfileTab({Key? key}) : super(key: key);

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _slideAnimation;
  
  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeIn),
      ),
    );
    
    _slideAnimation = Tween<double>(begin: 50.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );
    
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final classProvider = Provider.of<ClassProvider>(context);
    final user = authProvider.currentUser;
    final isLecturer = authProvider.isLecturer;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return FadeTransition(
          opacity: _fadeAnimation,
          child: Transform.translate(
            offset: Offset(0, _slideAnimation.value),
            child: child,
          ),
        );
      },
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Profile Header
              _buildProfileHeader(context, user, isLecturer, isDark),
              
              const SizedBox(height: 24),
              
              // User information
              _buildUserInfoSection(context, user, isLecturer, isDark),
              
              const SizedBox(height: 24),
              
              // Account settings
              _buildSettingsSection(
                context,
                authProvider,
                classProvider,
                isDark,
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildProfileHeader(
    BuildContext context,
    User? user,
    bool isLecturer,
    bool isDark,
  ) {
    return Row(
      children: [
        // Profile image with gradient border
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient:
                isLecturer
                ? AppTheme.secondaryGradient(isDark)
                : AppTheme.primaryGradient(isDark),
          ),
          child: CircleAvatar(
            radius: 40,
            backgroundColor:
                isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
            child: Icon(
              Icons.person,
              size: 40,
              color:
                  isLecturer
                      ? (isDark
                          ? AppTheme.darkSecondaryStart
                          : AppTheme.lightSecondaryStart)
                      : (isDark
                          ? AppTheme.darkPrimaryStart
                          : AppTheme.lightPrimaryStart),
            ),
          ),
        ),
        
        const SizedBox(width: 16),
        
        // User name and role
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                user?.fullName ?? 'User',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  gradient:
                      isLecturer
                      ? AppTheme.secondaryGradient(isDark)
                      : AppTheme.primaryGradient(isDark),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  isLecturer ? 'Lecturer' : 'Student',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
  
  Widget _buildUserInfoSection(
    BuildContext context,
    User? user,
    bool isLecturer,
    bool isDark,
  ) {
    // Different UI for student vs lecturer
    if (user == null) {
      return Container();
    }
    
    final infoItems = <Map<String, dynamic>>[];
    
    // Common fields
    infoItems.add({'icon': Icons.email, 'title': 'Email', 'value': user.email});
    
    // User type specific fields
    if (isLecturer) {
      final lecturer = user as Lecturer;
      infoItems.add({
        'icon': Icons.badge,
        'title': 'Staff ID',
        'value': lecturer.staffId,
      });
      infoItems.add({
        'icon': Icons.business,
        'title': 'Department',
        'value': lecturer.department,
      });
    } else {
      final student = user as Student;
      infoItems.add({
        'icon': Icons.numbers,
        'title': 'Student Number',
        'value': student.studentNumber,
      });
      infoItems.add({
        'icon': Icons.business,
        'title': 'Institution',
        'value': student.institution,
      });
      infoItems.add({
        'icon': Icons.school,
        'title': 'Level',
        'value': student.level,
      });
    }
    
    return GradientContainer(
      useSecondaryGradient: isLecturer,
      padding: const EdgeInsets.all(24),
      borderRadius: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ShaderMask(
            shaderCallback:
                (bounds) => (isLecturer
                    ? AppTheme.secondaryGradient(isDark)
                    : AppTheme.primaryGradient(isDark))
                .createShader(bounds),
            child: Text(
              'Profile Information',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 16),
          ...infoItems.map(
            (item) => _buildInfoItem(
                context,
                icon: item['icon'],
                title: item['title'],
                value: item['value'],
                isLecturer: isLecturer,
                isDark: isDark,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildInfoItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String value,
    required bool isLecturer,
    required bool isDark,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: (isLecturer
                      ? (isDark
                          ? AppTheme.darkSecondaryStart
                          : AppTheme.lightSecondaryStart)
                      : (isDark
                          ? AppTheme.darkPrimaryStart
                          : AppTheme.lightPrimaryStart))
                  .withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              size: 18,
              color:
                  isLecturer
                      ? (isDark
                          ? AppTheme.darkSecondaryStart
                          : AppTheme.lightSecondaryStart)
                      : (isDark
                          ? AppTheme.darkPrimaryStart
                          : AppTheme.lightPrimaryStart),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    color:
                        isDark
                            ? AppTheme.darkTextSecondary
                            : AppTheme.lightTextSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildSettingsSection(
    BuildContext context,
    AuthProvider authProvider,
    ClassProvider classProvider,
    bool isDark,
  ) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Account',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        _buildSettingItem(
          context,
          icon: Icons.edit,
          title: 'Edit Profile',
          subtitle: 'Update your personal information',
          onTap: () async {
            final result = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const EditProfileScreen(),
              ),
            );
            
            // Refresh the UI if profile was updated
            if (result == true) {
              setState(() {});
            }
          },
          isDark: isDark,
        ),
        const Divider(height: 1),
        
        // Theme Selection
        _buildThemeSelector(context, themeProvider, isDark),
        const Divider(height: 1),
        
        _buildSettingItem(
          context,
          icon: Icons.help_outline,
          title: 'Help & Support',
          subtitle: 'Contact us and FAQs',
          onTap: () {
            // Handle help
          },
          isDark: isDark,
        ),
        const Divider(height: 1),
        const SizedBox(height: 24),
        GradientButton(
          text: 'Sign Out',
          onPressed: () async {
            // Sign out and reset the class provider
            await authProvider.signOut(
              resetClassProvider: () => classProvider.reset(),
            );

            if (context.mounted &&
                authProvider.status == AuthStatus.unauthenticated) {
              // Navigate to login screen and clear the navigation stack
              // This ensures the user can't go back to authenticated screens
              Navigator.of(
                context,
              ).pushNamedAndRemoveUntil('/login', (route) => false);
            }
          },
          isLoading: authProvider.status == AuthStatus.loading,
          useSecondaryGradient: authProvider.isLecturer,
        ),
      ],
    );
  }
  
  Widget _buildThemeSelector(
    BuildContext context,
    ThemeProvider themeProvider,
    bool isDark,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.palette_outlined,
                size: 24,
                color:
                    isDark
                        ? AppTheme.darkTextSecondary
                        : AppTheme.lightTextSecondary,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Theme', style: TextStyle(fontSize: 16)),
                    const SizedBox(height: 4),
                    Text(
                      'Choose your preferred theme',
                      style: TextStyle(
                        fontSize: 14,
                        color:
                            isDark
                                ? AppTheme.darkTextSecondary
                                : AppTheme.lightTextSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildThemeOption(
                context: context,
                icon: Icons.light_mode,
                label: 'Light',
                isSelected: themeProvider.themeMode == ThemeMode.light,
                onTap: () => themeProvider.setThemeMode(ThemeMode.light),
                isDark: isDark,
              ),
              _buildThemeOption(
                context: context,
                icon: Icons.dark_mode,
                label: 'Dark',
                isSelected: themeProvider.themeMode == ThemeMode.dark,
                onTap: () => themeProvider.setThemeMode(ThemeMode.dark),
                isDark: isDark,
              ),
              _buildThemeOption(
                context: context,
                icon: Icons.settings_suggest,
                label: 'System',
                isSelected: themeProvider.themeMode == ThemeMode.system,
                onTap: () => themeProvider.setThemeMode(ThemeMode.system),
                isDark: isDark,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildThemeOption({
    required BuildContext context,
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color:
              isSelected
                  ? (isDark
                          ? AppTheme.darkPrimaryStart
                          : AppTheme.lightPrimaryStart)
                      .withOpacity(0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color:
                isSelected
                    ? (isDark
                        ? AppTheme.darkPrimaryStart
                        : AppTheme.lightPrimaryStart)
                    : (isDark
                        ? Colors.white.withOpacity(0.1)
                        : Colors.black.withOpacity(0.1)),
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color:
                  isSelected
                      ? (isDark
                          ? AppTheme.darkPrimaryStart
                          : AppTheme.lightPrimaryStart)
                      : (isDark
                          ? AppTheme.darkTextSecondary
                          : AppTheme.lightTextSecondary),
              size: 24,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color:
                    isSelected
                        ? (isDark
                            ? AppTheme.darkPrimaryStart
                            : AppTheme.lightPrimaryStart)
                        : (isDark
                            ? AppTheme.darkTextSecondary
                            : AppTheme.lightTextSecondary),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildSettingItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Row(
            children: [
              Icon(
                icon,
                size: 24,
                color:
                    isDark
                        ? AppTheme.darkTextSecondary
                        : AppTheme.lightTextSecondary,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 14,
                        color:
                            isDark
                                ? AppTheme.darkTextSecondary
                                : AppTheme.lightTextSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color:
                    isDark
                        ? AppTheme.darkTextSecondary
                        : AppTheme.lightTextSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
} 
