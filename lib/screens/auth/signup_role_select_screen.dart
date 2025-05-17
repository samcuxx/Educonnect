import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import 'student_signup_screen.dart';
import 'lecturer_signup_screen.dart';
import '../../widgets/custom_button.dart';

class SignupRoleSelectScreen extends StatelessWidget {
  const SignupRoleSelectScreen({Key? key}) : super(key: key);

  void _navigateToStudentSignup(BuildContext context) {
    // Clear any existing errors
    context.read<AuthProvider>().clearError();
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const StudentSignupScreen(),
      ),
    );
  }

  void _navigateToLecturerSignup(BuildContext context) {
    // Clear any existing errors
    context.read<AuthProvider>().clearError();
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const LecturerSignupScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Your Role'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 40),
            // App logo or icon
            Icon(
              Icons.school,
              size: 80,
              color: Theme.of(context).primaryColor,
            ),
            const SizedBox(height: 24),
            // Heading
            Text(
              'Join EduConnect',
              style: Theme.of(context).textTheme.headlineMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Are you a student or a lecturer?',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 48),
            // Student Option
            _buildRoleOption(
              context,
              title: 'Student',
              description: 'Access course materials, submit assignments, and track your progress',
              icon: Icons.person,
              onTap: () => _navigateToStudentSignup(context),
            ),
            const SizedBox(height: 24),
            // Lecturer Option
            _buildRoleOption(
              context,
              title: 'Lecturer',
              description: 'Create courses, manage content, and interact with students',
              icon: Icons.school,
              onTap: () => _navigateToLecturerSignup(context),
            ),
            const Spacer(),
            // Already have an account link
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('Already have an account?'),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Login'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoleOption(
    BuildContext context, {
    required String title,
    required String description,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).primaryColor),
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  color: Theme.of(context).primaryColor,
                  size: 36,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                color: Theme.of(context).primaryColor,
              ),
            ],
          ),
        ),
      ),
    );
  }
} 