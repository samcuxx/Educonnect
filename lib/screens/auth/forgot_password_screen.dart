import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/gradient_button.dart';
import '../../widgets/gradient_container.dart';
import '../../widgets/theme_toggle_button.dart';
import '../../widgets/otp_verification_dialog.dart';
import '../../utils/app_theme.dart';
import 'reset_password_screen.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({Key? key}) : super(key: key);

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();

  bool _isLoading = false;
  bool _isCheckingUser = false;
  String? _errorMessage;
  String? _userPhoneNumber;

  @override
  void dispose() {
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _navigateBack() {
    Navigator.pop(context);
  }

  Future<void> _checkUserExists() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isCheckingUser = true;
      _errorMessage = null;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final userPhone = await authProvider.getUserPhoneByEmail(
        _emailController.text.trim(),
      );

      if (userPhone != null) {
        setState(() {
          _userPhoneNumber = userPhone;
        });
        _sendOtp();
      } else {
        setState(() {
          _errorMessage =
              'No account found with this email address. Please check your email or create a new account.';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage =
            'An error occurred while checking your account. Please try again.';
      });
    } finally {
      setState(() {
        _isCheckingUser = false;
      });
    }
  }

  Future<void> _sendOtp() async {
    if (_userPhoneNumber == null) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final otpSent = await authProvider.sendOtp(_userPhoneNumber!);

      if (otpSent) {
        // Show OTP verification dialog
        final verified = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder:
              (context) =>
                  OtpVerificationDialog(phoneNumber: _userPhoneNumber!),
        );

        if (verified == true) {
          // OTP verification successful, navigate to reset password screen
          if (mounted) {
            Navigator.pushReplacement(
              context,
              PageRouteBuilder(
                settings: const RouteSettings(name: '/reset-password'),
                pageBuilder:
                    (context, animation, secondaryAnimation) =>
                        ResetPasswordScreen(
                          email: _emailController.text.trim(),
                        ),
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
                  return SlideTransition(
                    position: offsetAnimation,
                    child: child,
                  );
                },
                transitionDuration: const Duration(milliseconds: 500),
              ),
            );
          }
        } else {
          setState(() {
            _errorMessage = 'Verification was cancelled. Please try again.';
          });
        }
      } else {
        setState(() {
          _errorMessage = 'Failed to send verification code. Please try again.';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage =
            'An error occurred while sending the verification code. Please try again.';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
                          AppTheme.lightPrimaryStart.withOpacity(0.1),
                          AppTheme.lightPrimaryEnd.withOpacity(0.05),
                        ],
              ),
            ),
          ),

          // Content
          SafeArea(
            child: Column(
              children: [
                // Top bar with back button and theme toggle
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24.0,
                    vertical: 16.0,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      GestureDetector(
                        onTap: _navigateBack,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color:
                                isDark
                                    ? AppTheme.darkSurface
                                    : AppTheme.lightSurface,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.arrow_back,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ),
                      const ThemeToggleButton(),
                    ],
                  ),
                ),

                // Scrollable content
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24.0),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 20),

                          // Header with icon
                          Center(
                            child: Column(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: AppTheme.primaryGradient(isDark),
                                    boxShadow: [
                                      BoxShadow(
                                        color: (isDark
                                                ? AppTheme.darkPrimaryStart
                                                : AppTheme.lightPrimaryStart)
                                            .withOpacity(0.3),
                                        blurRadius: 20,
                                        offset: const Offset(0, 8),
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.lock_reset,
                                    size: 40,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 24),
                                ShaderMask(
                                  shaderCallback:
                                      (bounds) => AppTheme.primaryGradient(
                                        isDark,
                                      ).createShader(bounds),
                                  child: Text(
                                    'Reset Password',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.headlineSmall?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                      letterSpacing: 0.8,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Enter your registered email address and we\'ll send a verification code to your phone number',
                                  style: Theme.of(
                                    context,
                                  ).textTheme.bodyMedium?.copyWith(
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

                          const SizedBox(height: 40),

                          // Form in gradient container
                          GradientContainer(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Email field
                                CustomTextField(
                                  controller: _emailController,
                                  labelText: 'Email Address',
                                  hintText: 'Enter your registered email',
                                  keyboardType: TextInputType.emailAddress,
                                  prefixIcon: const Icon(Icons.email_outlined),
                                  enabled: !_isLoading && !_isCheckingUser,
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Please enter your email address';
                                    }
                                    if (!RegExp(
                                      r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                                    ).hasMatch(value)) {
                                      return 'Please enter a valid email address';
                                    }
                                    return null;
                                  },
                                ),

                                const SizedBox(height: 16),

                                // Info text
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: (isDark
                                            ? AppTheme.darkPrimaryStart
                                            : AppTheme.lightPrimaryStart)
                                        .withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: (isDark
                                              ? AppTheme.darkPrimaryStart
                                              : AppTheme.lightPrimaryStart)
                                          .withOpacity(0.3),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.info_outline,
                                        color:
                                            isDark
                                                ? AppTheme.darkPrimaryStart
                                                : AppTheme.lightPrimaryStart,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          'We\'ll verify your identity using the phone number associated with your account.',
                                          style: TextStyle(
                                            fontSize: 13,
                                            color:
                                                isDark
                                                    ? AppTheme.darkTextSecondary
                                                    : AppTheme
                                                        .lightTextSecondary,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 24),

                          // Error message
                          if (_errorMessage != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              margin: const EdgeInsets.only(bottom: 24),
                              decoration: BoxDecoration(
                                color: Colors.red.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: Colors.red.withOpacity(0.3),
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.error_outline,
                                    color: Colors.red,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      _errorMessage!,
                                      style: const TextStyle(
                                        color: Colors.red,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                          // Send verification button
                          GradientButton(
                            text: 'Send Verification Code',
                            onPressed: _checkUserExists,
                            isLoading: _isLoading || _isCheckingUser,
                          ),

                          const SizedBox(height: 24),

                          // Back to login link
                          Center(
                            child: TextButton(
                              onPressed: _navigateBack,
                              child: RichText(
                                text: TextSpan(
                                  text: 'Remember your password? ',
                                  style: TextStyle(
                                    color:
                                        isDark
                                            ? AppTheme.darkTextSecondary
                                            : AppTheme.lightTextSecondary,
                                    fontSize: 14,
                                  ),
                                  children: [
                                    TextSpan(
                                      text: 'Sign In',
                                      style: TextStyle(
                                        color:
                                            isDark
                                                ? AppTheme.darkPrimaryStart
                                                : AppTheme.lightPrimaryStart,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
