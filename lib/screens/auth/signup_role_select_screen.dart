import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../utils/app_theme.dart';
import '../../utils/animation_util.dart';
import 'student_signup_screen.dart';
import 'lecturer_signup_screen.dart';

class SignupRoleSelectScreen extends StatelessWidget {
  const SignupRoleSelectScreen({Key? key}) : super(key: key);

  void _navigateToStudentSignup(BuildContext context) {
    // Clear any existing errors
    context.read<AuthProvider>().clearError();

    // Use named route for consistent navigation with route protection
    Navigator.pushNamed(context, '/signup/student');
  }

  void _navigateToLecturerSignup(BuildContext context) {
    // Clear any existing errors
    context.read<AuthProvider>().clearError();

    // Use named route for consistent navigation with route protection
    Navigator.pushNamed(context, '/signup/lecturer');
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkBackground : AppTheme.lightBackground,
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Top bar with back button
                FadeInLeft(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color:
                                isDark
                                    ? AppTheme.darkSurface
                                    : AppTheme.lightSurface,
                          ),
                          child: Icon(
                            Icons.arrow_back,
                            color: Theme.of(context).colorScheme.primary,
                            size: 20,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 40),

                // App logo with gradient
                FadeInUp(
                  delay: const Duration(milliseconds: 100),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: AppTheme.primaryGradient(isDark),
                    ),
                    child: const Icon(
                      Icons.school,
                      size: 48,
                      color: Colors.white,
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Heading with gradient
                FadeInUp(
                  delay: const Duration(milliseconds: 200),
                  child: Column(
                    children: [
                      ShaderMask(
                        shaderCallback: (Rect bounds) {
                          return AppTheme.primaryGradient(
                            isDark,
                          ).createShader(bounds);
                        },
                        child: Text(
                          'EduConnect',
                          style: Theme.of(
                            context,
                          ).textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 1.2,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Join Our Community',
                        style: Theme.of(context).textTheme.titleMedium,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Are you a student or a lecturer?',
                        style: Theme.of(context).textTheme.bodyMedium,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 48),

                // Role options
                FadeInUp(
                  delay: const Duration(milliseconds: 300),
                  child: _buildRoleOption(
                    context,
                    title: 'Student',
                    description:
                        'Access course materials, submit assignments, and track your progress',
                    icon: Icons.person_outlined,
                    iconGradient: AppTheme.primaryGradient(isDark),
                    onTap: () => _navigateToStudentSignup(context),
                  ),
                ),

                const SizedBox(height: 24),

                FadeInUp(
                  delay: const Duration(milliseconds: 400),
                  child: _buildRoleOption(
                    context,
                    title: 'Lecturer',
                    description:
                        'Create courses, manage content, and interact with students',
                    icon: Icons.school_outlined,
                    iconGradient: AppTheme.secondaryGradient(isDark),
                    onTap: () => _navigateToLecturerSignup(context),
                  ),
                ),

                const Spacer(),

                // Already have an account link
                FadeInUp(
                  delay: const Duration(milliseconds: 450),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Already have an account?',
                        style: TextStyle(
                          fontWeight: FontWeight.w400,
                          fontSize: 14,
                        ),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(
                          'Login',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRoleOption(
    BuildContext context, {
    required String title,
    required String description,
    required IconData icon,
    required Gradient iconGradient,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28),
        side: BorderSide(
          color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
          width: 1,
        ),
      ),
      color: isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(28),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Row(
            children: [
              // Icon with gradient background
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: iconGradient,
                  borderRadius: BorderRadius.circular(28),
                ),
                child: Icon(icon, color: Colors.white, size: 24),
              ),

              const SizedBox(width: 16),

              // Text content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),

              // Arrow icon
              ShaderMask(
                shaderCallback: (Rect bounds) {
                  return iconGradient.createShader(bounds);
                },
                child: const Icon(
                  Icons.arrow_forward_ios,
                  color: Colors.white,
                  size: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
