import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../utils/app_theme.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'About',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold),
        ),
        backgroundColor: isDark ? AppTheme.darkSurface : Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // App logo
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color:
                      isDark
                          ? AppTheme.darkPrimaryStart.withOpacity(0.1)
                          : AppTheme.lightPrimaryStart.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.school,
                  size: 64,
                  color:
                      isDark
                          ? AppTheme.darkPrimaryStart
                          : AppTheme.lightPrimaryStart,
                ),
              ),
              const SizedBox(height: 16),

              // App name
              Text(
                'EduConnect',
                style: GoogleFonts.inter(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color:
                      isDark
                          ? AppTheme.darkTextPrimary
                          : AppTheme.lightTextPrimary,
                ),
              ),

              // App version
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Text(
                  'Version 1.0.0 (Build 1)',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color:
                        isDark
                            ? AppTheme.darkTextSecondary
                            : AppTheme.lightTextSecondary,
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // Description section
              _buildSection(
                title: 'About EduConnect',
                content:
                    'EduConnect is a collaborative learning platform designed to streamline communication between lecturers and students. Our mission is to make education more accessible and interactive through intuitive technology.',
                isDark: isDark,
              ),

              const SizedBox(height: 24),

              // Features section
              _buildSection(
                title: 'Key Features',
                content:
                    '• Seamless class management\n• Resource sharing and access\n• Offline support for learning on the go\n• Interactive assignments and submissions\n• Real-time notifications',
                isDark: isDark,
              ),

              const SizedBox(height: 24),

              // Developer info section
              _buildSection(
                title: 'Developer',
                content:
                    'EduConnect is developed by EduTech Solutions.\n\nContact: support@educonnect.edu',
                isDark: isDark,
              ),

              const SizedBox(height: 24),

              // Legal links
              _buildLegalLinks(context, isDark),

              const SizedBox(height: 32),

              // Copyright notice
              Text(
                '© ${DateTime.now().year} EduTech Solutions. All rights reserved.',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color:
                      isDark
                          ? AppTheme.darkTextSecondary
                          : AppTheme.lightTextSecondary,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required String content,
    required bool isDark,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
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
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color:
                  isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            content,
            style: GoogleFonts.inter(
              fontSize: 14,
              color:
                  isDark
                      ? AppTheme.darkTextSecondary
                      : AppTheme.lightTextSecondary,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegalLinks(BuildContext context, bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildLegalLink(
          title: 'Privacy Policy',
          onTap: () {
            // TODO: Navigate to privacy policy screen
          },
          isDark: isDark,
        ),
        _buildLegalLink(
          title: 'Terms of Service',
          onTap: () {
            // TODO: Navigate to terms of service screen
          },
          isDark: isDark,
        ),
        _buildLegalLink(
          title: 'Licenses',
          onTap: () {
            showLicensePage(
              context: context,
              applicationName: 'EduConnect',
              applicationVersion: '1.0.0',
              applicationIcon: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Icon(
                  Icons.school,
                  size: 48,
                  color:
                      isDark
                          ? AppTheme.darkPrimaryStart
                          : AppTheme.lightPrimaryStart,
                ),
              ),
            );
          },
          isDark: isDark,
        ),
      ],
    );
  }

  Widget _buildLegalLink({
    required String title,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
        child: Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color:
                isDark ? AppTheme.darkPrimaryStart : AppTheme.lightPrimaryStart,
            decoration: TextDecoration.underline,
          ),
        ),
      ),
    );
  }
}
