import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/gradient_button.dart';
import '../../utils/app_theme.dart';
import '../../utils/animation_util.dart';
import 'signup_role_select_screen.dart';
import '../../screens/dashboard/dashboard_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _togglePasswordVisibility() {
    setState(() {
      _obscurePassword = !_obscurePassword;
    });
  }

  Future<void> _login() async {
    if (_formKey.currentState!.validate()) {
      await context.read<AuthProvider>().signIn(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      // Navigate to dashboard if authentication is successful
      if (!mounted) return;
      if (context.read<AuthProvider>().status == AuthStatus.authenticated) {
        Navigator.of(context).pushAndRemoveUntil(
          PageRouteBuilder(
            pageBuilder:
                (context, animation, secondaryAnimation) =>
                    const DashboardScreen(),
            transitionsBuilder: (
              context,
              animation,
              secondaryAnimation,
              child,
            ) {
              const begin = Offset(1.0, 0.0);
              const end = Offset.zero;
              const curve = Curves.easeOutQuint;

              var tween = Tween(
                begin: begin,
                end: end,
              ).chain(CurveTween(curve: curve));
              var offsetAnimation = animation.drive(tween);

              return SlideTransition(position: offsetAnimation, child: child);
            },
            transitionDuration: const Duration(milliseconds: 500),
          ),
          (route) => false, // This will remove all previous routes
        );
      }
    }
  }

  void _navigateToSignup() {
    // Clear any existing errors before navigating
    context.read<AuthProvider>().clearError();

    // Use named route for signup to ensure it works with route protection
    Navigator.pushNamed(context, '/signup');
  }

  void _navigateToForgotPassword() {
    // Clear any existing errors before navigating
    context.read<AuthProvider>().clearError();

    // Use named route for forgot password
    Navigator.pushNamed(context, '/forgot-password');
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkBackground : AppTheme.lightBackground,
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
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

                  // Welcome text with gradient
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
                          'Welcome Back',
                          style: Theme.of(context).textTheme.titleMedium,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Sign in to continue',
                          style: Theme.of(context).textTheme.bodyMedium,
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 40),

                  // Login form
                  FadeInUp(
                    delay: const Duration(milliseconds: 300),
                    child: Column(
                      children: [
                        // Email field
                        CustomTextField(
                          controller: _emailController,
                          labelText: 'Email',
                          hintText: 'Enter your email',
                          keyboardType: TextInputType.emailAddress,
                          prefixIcon: const Icon(Icons.email_outlined),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter your email';
                            }
                            if (!RegExp(
                              r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                            ).hasMatch(value)) {
                              return 'Please enter a valid email';
                            }
                            return null;
                          },
                        ),

                        const SizedBox(height: 16),

                        // Password field
                        CustomTextField(
                          controller: _passwordController,
                          labelText: 'Password',
                          hintText: 'Enter your password',
                          obscureText: _obscurePassword,
                          prefixIcon: const Icon(Icons.lock_outlined),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                              color:
                                  isDark
                                      ? AppTheme.darkTextSecondary
                                      : AppTheme.lightTextSecondary,
                            ),
                            onPressed: _togglePasswordVisibility,
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter your password';
                            }
                            if (value.length < 6) {
                              return 'Password must be at least 6 characters';
                            }
                            return null;
                          },
                        ),

                        const SizedBox(height: 24),

                        // Login button
                        GradientButton(
                          text: 'Login',
                          onPressed: _login,
                          isLoading: authProvider.status == AuthStatus.loading,
                        ),
                      ],
                    ),
                  ),

                  // Forgot password link
                  FadeInUp(
                    delay: const Duration(milliseconds: 350),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 16.0, right: 8.0),
                        child: TextButton(
                          onPressed: _navigateToForgotPassword,
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                          ),
                          child: Text(
                            'Forgot Password?',
                            style: TextStyle(
                              fontWeight: FontWeight.w500,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Error message
                  if (authProvider.errorMessage != null)
                    FadeInUp(
                      delay: const Duration(milliseconds: 350),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color:
                              isDark
                                  ? Color(0xFF222f43).withOpacity(0.3)
                                  : Color(0xFFe5e5e5).withOpacity(0.5),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color:
                                isDark ? Color(0xFF222f43) : Color(0xFFe5e5e5),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.red.withOpacity(0.2),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.error_outline,
                                color: Colors.red,
                                size: 16,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                authProvider.errorMessage!,
                                style: TextStyle(
                                  color: Colors.red.shade300,
                                  fontWeight: FontWeight.w400,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  const SizedBox(height: 24),

                  // Sign up link
                  FadeInUp(
                    delay: const Duration(milliseconds: 450),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "Don't have an account?",
                          style: TextStyle(
                            fontWeight: FontWeight.w400,
                            fontSize: 14,
                          ),
                        ),
                        TextButton(
                          onPressed: _navigateToSignup,
                          child: Text(
                            'Sign Up',
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
      ),
    );
  }
}
