import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/auth_provider.dart';
import '../../providers/class_provider.dart';
import '../../providers/theme_provider.dart';
import '../../utils/app_theme.dart';
import '../../widgets/gradient_button.dart';
import '../../widgets/cached_profile_image.dart';
import '../../models/user_model.dart';
import '../profile/edit_profile_screen.dart';

class ProfileTab extends StatefulWidget {
  const ProfileTab({Key? key}) : super(key: key);

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final classProvider = Provider.of<ClassProvider>(context);
    final user = authProvider.currentUser;
    final isLecturer = authProvider.isLecturer;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Section
            _buildHeader(context, user, isLecturer, isDark),

            const SizedBox(height: 24),

            // User Information Card
            _buildUserInfoCard(context, user, isLecturer, isDark),

            const SizedBox(height: 20),

            // Account Settings Card
            _buildAccountCard(context, authProvider, isDark),

            const SizedBox(height: 20),

            // Preferences Card
            _buildPreferencesCard(context, isDark),

            const SizedBox(height: 20),

            // Support Card
            _buildSupportCard(context, isDark),

            const SizedBox(height: 32),

            // Sign Out Button
            _buildSignOutButton(
              context,
              authProvider,
              classProvider,
              isLecturer,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    User? user,
    bool isLecturer,
    bool isDark,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            // User profile image or initials
            CachedProfileImage(
              imageUrl: user?.profileImageUrl,
              fullName: user?.fullName ?? 'User',
              radius: 30,
              isLecturer: isLecturer,
              isDark: isDark,
              gradientPadding: const EdgeInsets.all(2),
            ),

            const SizedBox(width: 16),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user?.fullName ?? 'User',
                    style: GoogleFonts.inter(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color:
                          isDark
                              ? AppTheme.darkTextPrimary
                              : AppTheme.lightTextPrimary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),

                  const SizedBox(height: 6),

                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: (isLecturer
                              ? (isDark
                                  ? AppTheme.darkSecondaryStart
                                  : AppTheme.lightSecondaryStart)
                              : (isDark
                                  ? AppTheme.darkPrimaryStart
                                  : AppTheme.lightPrimaryStart))
                          .withOpacity(0.1),
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(
                        color:
                            isLecturer
                                ? (isDark
                                    ? AppTheme.darkSecondaryStart
                                    : AppTheme.lightSecondaryStart)
                                : (isDark
                                    ? AppTheme.darkPrimaryStart
                                    : AppTheme.lightPrimaryStart),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      isLecturer ? 'Lecturer' : 'Student',
                      style: GoogleFonts.inter(
                        color:
                            isLecturer
                                ? (isDark
                                    ? AppTheme.darkSecondaryStart
                                    : AppTheme.lightSecondaryStart)
                                : (isDark
                                    ? AppTheme.darkPrimaryStart
                                    : AppTheme.lightPrimaryStart),
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildUserInfoCard(
    BuildContext context,
    User? user,
    bool isLecturer,
    bool isDark,
  ) {
    if (user == null) return const SizedBox.shrink();

    final infoItems = <Map<String, dynamic>>[];

    // Common fields
    infoItems.add({
      'icon': Icons.email_outlined,
      'title': 'Email Address',
      'value': user.email,
    });

    // User type specific fields
    if (isLecturer) {
      final lecturer = user as Lecturer;
      infoItems.add({
        'icon': Icons.badge_outlined,
        'title': 'Staff ID',
        'value': lecturer.staffId,
      });
      infoItems.add({
        'icon': Icons.business_outlined,
        'title': 'Department',
        'value': lecturer.department,
      });
    } else {
      final student = user as Student;
      infoItems.add({
        'icon': Icons.numbers_outlined,
        'title': 'Student Number',
        'value': student.studentNumber,
      });
      infoItems.add({
        'icon': Icons.business_outlined,
        'title': 'Institution',
        'value': student.institution,
      });
      infoItems.add({
        'icon': Icons.school_outlined,
        'title': 'Academic Level',
        'value': student.level,
      });
    }

    return _buildCard(
      context,
      title: 'Personal Information',
      icon: Icons.person_outline,
      isDark: isDark,
      child: Column(
        children:
            infoItems.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              return Column(
                children: [
                  _buildInfoRow(
                    icon: item['icon'],
                    title: item['title'],
                    value: item['value'],
                    isDark: isDark,
                  ),
                  if (index < infoItems.length - 1) const SizedBox(height: 16),
                ],
              );
            }).toList(),
      ),
    );
  }

  Widget _buildAccountCard(
    BuildContext context,
    AuthProvider authProvider,
    bool isDark,
  ) {
    return _buildCard(
      context,
      title: 'Account',
      icon: Icons.settings_outlined,
      isDark: isDark,
      child: Column(
        children: [
          _buildActionRow(
            icon: Icons.edit_outlined,
            title: 'Edit Profile',
            subtitle: 'Update your personal information',
            onTap: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const EditProfileScreen(),
                ),
              );
              if (result == true && mounted) setState(() {});
            },
            isDark: isDark,
          ),

          const SizedBox(height: 16),

          _buildActionRow(
            icon: Icons.security_outlined,
            title: 'Privacy & Security',
            subtitle: 'Manage your account security',
            onTap: () {
              // TODO: Navigate to security settings
            },
            isDark: isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildPreferencesCard(BuildContext context, bool isDark) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return _buildCard(
      context,
      title: 'Preferences',
      icon: Icons.tune_outlined,
      isDark: isDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.palette_outlined,
                size: 20,
                color:
                    isDark
                        ? AppTheme.darkTextSecondary
                        : AppTheme.lightTextSecondary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Theme',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color:
                            isDark
                                ? AppTheme.darkTextPrimary
                                : AppTheme.lightTextPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Choose your preferred appearance',
                      style: GoogleFonts.inter(
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
            children: [
              Expanded(
                child: _buildThemeOption(
                  context: context,
                  icon: Icons.light_mode_outlined,
                  label: 'Light',
                  isSelected: themeProvider.themeMode == ThemeMode.light,
                  onTap: () => themeProvider.setThemeMode(ThemeMode.light),
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildThemeOption(
                  context: context,
                  icon: Icons.dark_mode_outlined,
                  label: 'Dark',
                  isSelected: themeProvider.themeMode == ThemeMode.dark,
                  onTap: () => themeProvider.setThemeMode(ThemeMode.dark),
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildThemeOption(
                  context: context,
                  icon: Icons.settings_suggest_outlined,
                  label: 'System',
                  isSelected: themeProvider.themeMode == ThemeMode.system,
                  onTap: () => themeProvider.setThemeMode(ThemeMode.system),
                  isDark: isDark,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSupportCard(BuildContext context, bool isDark) {
    return _buildCard(
      context,
      title: 'Support',
      icon: Icons.help_outline,
      isDark: isDark,
      child: Column(
        children: [
          _buildActionRow(
            icon: Icons.help_center_outlined,
            title: 'Help Center',
            subtitle: 'Find answers to common questions',
            onTap: () {
              // TODO: Navigate to help center
            },
            isDark: isDark,
          ),

          const SizedBox(height: 16),

          _buildActionRow(
            icon: Icons.feedback_outlined,
            title: 'Send Feedback',
            subtitle: 'Help us improve the app',
            onTap: () {
              // TODO: Navigate to feedback
            },
            isDark: isDark,
          ),

          const SizedBox(height: 16),

          _buildActionRow(
            icon: Icons.info_outline,
            title: 'About',
            subtitle: 'App version and information',
            onTap: () {
              // TODO: Show about dialog
            },
            isDark: isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    required bool isDark,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                size: 22,
                color:
                    isDark
                        ? AppTheme.darkTextPrimary
                        : AppTheme.lightTextPrimary,
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color:
                      isDark
                          ? AppTheme.darkTextPrimary
                          : AppTheme.lightTextPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          child,
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String title,
    required String value,
    required bool isDark,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkBorder : AppTheme.lightBackground,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
              width: 1,
            ),
          ),
          child: Icon(
            icon,
            size: 18,
            color:
                isDark
                    ? AppTheme.darkTextSecondary
                    : AppTheme.lightTextSecondary,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color:
                      isDark
                          ? AppTheme.darkTextSecondary
                          : AppTheme.lightTextSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color:
                      isDark
                          ? AppTheme.darkTextPrimary
                          : AppTheme.lightTextPrimary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionRow({
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
        borderRadius: BorderRadius.circular(28),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(28)),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color:
                      isDark ? AppTheme.darkBorder : AppTheme.lightBackground,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
                    width: 1,
                  ),
                ),
                child: Icon(
                  icon,
                  size: 18,
                  color:
                      isDark
                          ? AppTheme.darkTextSecondary
                          : AppTheme.lightTextSecondary,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color:
                            isDark
                                ? AppTheme.darkTextPrimary
                                : AppTheme.lightTextPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: GoogleFonts.inter(
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
                size: 20,
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
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color:
              isSelected
                  ? (isDark
                          ? AppTheme.darkPrimaryStart
                          : AppTheme.lightPrimaryStart)
                      .withOpacity(0.1)
                  : (isDark ? AppTheme.darkBorder : AppTheme.lightBackground),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color:
                isSelected
                    ? (isDark
                        ? AppTheme.darkPrimaryStart
                        : AppTheme.lightPrimaryStart)
                    : (isDark ? AppTheme.darkBorder : AppTheme.lightBorder),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
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
              size: 20,
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
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

  Widget _buildSignOutButton(
    BuildContext context,
    AuthProvider authProvider,
    ClassProvider classProvider,
    bool isLecturer,
  ) {
    return SizedBox(
      width: double.infinity,
      child: GradientButton(
        text: 'Sign Out',
        onPressed: () async {
          await authProvider.signOut(
            resetClassProvider: () => classProvider.reset(),
          );

          if (context.mounted &&
              authProvider.status == AuthStatus.unauthenticated) {
            Navigator.of(
              context,
            ).pushNamedAndRemoveUntil('/login', (route) => false);
          }
        },
        isLoading: authProvider.status == AuthStatus.loading,
        useSecondaryGradient: isLecturer,
      ),
    );
  }
}
