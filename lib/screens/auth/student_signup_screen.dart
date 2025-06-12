import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/gradient_button.dart';
import '../../widgets/otp_verification_dialog.dart';
import '../../utils/app_theme.dart';
import '../../screens/dashboard/dashboard_screen.dart';

class StudentSignupScreen extends StatefulWidget {
  const StudentSignupScreen({Key? key}) : super(key: key);

  @override
  State<StudentSignupScreen> createState() => _StudentSignupScreenState();
}

class _StudentSignupScreenState extends State<StudentSignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _studentNumberController = TextEditingController();
  final _institutionController = TextEditingController();
  final _levelController = TextEditingController();
  final _phoneNumberController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isPhoneVerified = false;
  bool _isCheckingEmail = false;
  bool _isCheckingPhone = false;
  bool _isSendingOtp = false;
  DateTime? _lastOtpSentTime;
  String? _emailError;
  String? _phoneError;

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _studentNumberController.dispose();
    _institutionController.dispose();
    _levelController.dispose();
    _phoneNumberController.dispose();
    super.dispose();
  }

  void _togglePasswordVisibility() {
    setState(() {
      _obscurePassword = !_obscurePassword;
    });
  }

  void _toggleConfirmPasswordVisibility() {
    setState(() {
      _obscureConfirmPassword = !_obscureConfirmPassword;
    });
  }

  void _navigateBack() {
    // Clear any errors before navigating back
    context.read<AuthProvider>().clearError();
    Navigator.pop(context);
  }

  Future<void> _checkEmailAvailability(String email) async {
    if (email.isEmpty ||
        !RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email)) {
      setState(() {
        _emailError = null;
      });
      return;
    }

    setState(() {
      _isCheckingEmail = true;
      _emailError = null;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final exists = await authProvider.checkEmailExists(email);

      if (mounted) {
        setState(() {
          _emailError =
              exists
                  ? 'This email is already registered. Please use a different email or try logging in.'
                  : null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _emailError = 'Unable to verify email. Please try again.';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isCheckingEmail = false;
        });
      }
    }
  }

  Future<void> _checkPhoneAvailability(String phone) async {
    if (phone.isEmpty) {
      setState(() {
        _phoneError = null;
      });
      return;
    }

    setState(() {
      _isCheckingPhone = true;
      _phoneError = null;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final exists = await authProvider.checkPhoneExists(phone);

      if (mounted) {
        setState(() {
          _phoneError =
              exists
                  ? 'This phone number is already registered. Please use a different number.'
                  : null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _phoneError = 'Unable to verify phone number. Please try again.';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isCheckingPhone = false;
        });
      }
    }
  }

  Future<void> _verifyPhoneNumber() async {
    final phoneNumber = _phoneNumberController.text.trim();
    if (phoneNumber.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a phone number first'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_phoneError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_phoneError!), backgroundColor: Colors.red),
      );
      return;
    }

    // Check rate limiting - prevent multiple OTP sends within 60 seconds
    if (_lastOtpSentTime != null) {
      final timeSinceLastOtp = DateTime.now().difference(_lastOtpSentTime!);
      if (timeSinceLastOtp.inSeconds < 60) {
        final remainingSeconds = 60 - timeSinceLastOtp.inSeconds;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Please wait $remainingSeconds seconds before requesting a new code',
            ),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
    }

    // Prevent multiple simultaneous OTP sends
    if (_isSendingOtp) {
      return;
    }

    setState(() {
      _isSendingOtp = true;
    });

    try {
      // Send OTP
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final otpSent = await authProvider.sendOtp(phoneNumber);

      if (!otpSent) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Failed to send verification code. Please try again.',
            ),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Update last OTP sent time
      setState(() {
        _lastOtpSentTime = DateTime.now();
      });

      // Show OTP verification dialog
      final verified = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder:
            (context) => OtpVerificationDialog(
              phoneNumber: phoneNumber,
              onVerificationComplete: () {
                setState(() {
                  _isPhoneVerified = true;
                });
              },
            ),
      );

      if (verified == true) {
        setState(() {
          _isPhoneVerified = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Phone number verified successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } finally {
      setState(() {
        _isSendingOtp = false;
      });
    }
  }

  Future<void> _signUp() async {
    if (_formKey.currentState!.validate()) {
      // Check if phone number is provided and verified
      final phoneNumber = _phoneNumberController.text.trim();
      if (phoneNumber.isNotEmpty && !_isPhoneVerified) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Please verify your phone number before creating account',
            ),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      // Check for email and phone errors
      if (_emailError != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_emailError!), backgroundColor: Colors.red),
        );
        return;
      }

      if (_phoneError != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_phoneError!), backgroundColor: Colors.red),
        );
        return;
      }

      await context.read<AuthProvider>().signUpStudent(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        fullName: _fullNameController.text.trim(),
        studentNumber: _studentNumberController.text.trim(),
        institution: _institutionController.text.trim(),
        level: _levelController.text.trim(),
        phoneNumber: phoneNumber.isNotEmpty ? phoneNumber : null,
      );

      // If signup is successful, navigate to dashboard
      if (!mounted) return;
      if (context.read<AuthProvider>().status == AuthStatus.authenticated) {
        // Navigate to dashboard with replacement (removes previous screens from stack)
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
          child: Column(
            children: [
              // Top bar with back button
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24.0,
                  vertical: 16.0,
                ),
                child: Row(
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
                        ),
                        child: Icon(
                          Icons.arrow_back,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
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
                        // Page title with gradient
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ShaderMask(
                              shaderCallback:
                                  (bounds) => AppTheme.primaryGradient(
                                    isDark,
                                  ).createShader(bounds),
                              child: Text(
                                'Student Account',
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
                              'Please fill in your details',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ],
                        ),

                        const SizedBox(height: 32),

                        // Form fields
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Full Name
                            CustomTextField(
                              controller: _fullNameController,
                              labelText: 'Full Name',
                              hintText: 'Enter your full name',
                              prefixIcon: const Icon(Icons.person_outlined),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter your full name';
                                }
                                return null;
                              },
                            ),

                            // Email
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                CustomTextField(
                                  controller: _emailController,
                                  labelText: 'Email',
                                  hintText: 'Enter your email',
                                  keyboardType: TextInputType.emailAddress,
                                  prefixIcon: const Icon(Icons.email_outlined),
                                  suffixIcon:
                                      _isCheckingEmail
                                          ? const SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: Padding(
                                              padding: EdgeInsets.all(12.0),
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                              ),
                                            ),
                                          )
                                          : _emailError != null
                                          ? const Icon(
                                            Icons.error_outlined,
                                            color: Colors.red,
                                          )
                                          : _emailController.text.isNotEmpty
                                          ? const Icon(
                                            Icons.check_circle_outlined,
                                            color: Colors.green,
                                          )
                                          : null,
                                  onChanged: (value) {
                                    // Debounce email checking
                                    Future.delayed(
                                      const Duration(milliseconds: 1000),
                                      () {
                                        if (_emailController.text == value &&
                                            value.isNotEmpty) {
                                          _checkEmailAvailability(value);
                                        }
                                      },
                                    );
                                  },
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Please enter your email';
                                    }
                                    if (!RegExp(
                                      r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                                    ).hasMatch(value)) {
                                      return 'Please enter a valid email';
                                    }
                                    if (_emailError != null) {
                                      return _emailError;
                                    }
                                    return null;
                                  },
                                ),
                                if (_emailError != null)
                                  Padding(
                                    padding: const EdgeInsets.only(
                                      top: 8.0,
                                      left: 12.0,
                                    ),
                                    child: Text(
                                      _emailError!,
                                      style: const TextStyle(
                                        color: Colors.red,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                              ],
                            ),

                            // Password
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
                                  return 'Please enter a password';
                                }
                                if (value.length < 6) {
                                  return 'Password must be at least 6 characters';
                                }
                                return null;
                              },
                            ),

                            // Confirm Password
                            CustomTextField(
                              controller: _confirmPasswordController,
                              labelText: 'Confirm Password',
                              hintText: 'Confirm your password',
                              obscureText: _obscureConfirmPassword,
                              prefixIcon: const Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscureConfirmPassword
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                  color:
                                      isDark
                                          ? AppTheme.darkTextSecondary
                                          : AppTheme.lightTextSecondary,
                                ),
                                onPressed: _toggleConfirmPasswordVisibility,
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please confirm your password';
                                }
                                if (value != _passwordController.text) {
                                  return 'Passwords do not match';
                                }
                                return null;
                              },
                            ),

                            // Student Number
                            CustomTextField(
                              controller: _studentNumberController,
                              labelText: 'Student Number',
                              hintText: 'Enter your student number',
                              prefixIcon: const Icon(Icons.numbers_outlined),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter your student number';
                                }
                                return null;
                              },
                            ),

                            // Institution
                            CustomTextField(
                              controller: _institutionController,
                              labelText: 'Institution',
                              hintText: 'Enter your institution name',
                              prefixIcon: const Icon(Icons.business_outlined),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter your institution';
                                }
                                return null;
                              },
                            ),

                            // Level/Year
                            CustomTextField(
                              controller: _levelController,
                              labelText: 'Level/Year',
                              hintText: 'Enter your current level or year',
                              prefixIcon: const Icon(Icons.school_outlined),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter your level/year';
                                }
                                return null;
                              },
                            ),

                            // Phone Number
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: CustomTextField(
                                        controller: _phoneNumberController,
                                        labelText:
                                            'Phone Number (for SMS notifications)',
                                        hintText:
                                            'Enter your phone number (optional)',
                                        keyboardType: TextInputType.phone,
                                        prefixIcon: const Icon(
                                          Icons.phone_outlined,
                                        ),
                                        suffixIcon:
                                            _isCheckingPhone
                                                ? const SizedBox(
                                                  width: 20,
                                                  height: 20,
                                                  child: Padding(
                                                    padding: EdgeInsets.all(
                                                      12.0,
                                                    ),
                                                    child:
                                                        CircularProgressIndicator(
                                                          strokeWidth: 2,
                                                        ),
                                                  ),
                                                )
                                                : _phoneError != null
                                                ? const Icon(
                                                  Icons.error_outlined,
                                                  color: Colors.red,
                                                )
                                                : _isPhoneVerified
                                                ? const Icon(
                                                  Icons.verified_outlined,
                                                  color: Colors.green,
                                                )
                                                : null,
                                        onChanged: (value) {
                                          // Debounce phone checking
                                          Future.delayed(
                                            const Duration(milliseconds: 1000),
                                            () {
                                              if (_phoneNumberController.text ==
                                                      value &&
                                                  value.isNotEmpty) {
                                                _checkPhoneAvailability(value);
                                              }
                                            },
                                          );
                                          // Reset verification status when phone changes
                                          if (_isPhoneVerified) {
                                            setState(() {
                                              _isPhoneVerified = false;
                                            });
                                          }
                                        },
                                        validator: (value) {
                                          if (value != null &&
                                              value.isNotEmpty) {
                                            // Basic phone number validation
                                            if (!RegExp(
                                              r'^\+?[0-9]{10,15}$',
                                            ).hasMatch(value)) {
                                              return 'Please enter a valid phone number';
                                            }
                                            if (_phoneError != null) {
                                              return _phoneError;
                                            }
                                          }
                                          return null;
                                        },
                                      ),
                                    ),
                                    if (_phoneNumberController
                                            .text
                                            .isNotEmpty &&
                                        _phoneError == null)
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          left: 8.0,
                                        ),
                                        child: Container(
                                          height: 50,
                                          decoration: BoxDecoration(
                                            gradient:
                                                _isPhoneVerified
                                                    ? LinearGradient(
                                                      colors: [
                                                        Colors.green.shade400,
                                                        Colors.green.shade600,
                                                      ],
                                                    )
                                                    : (_isSendingOtp
                                                        ? LinearGradient(
                                                          colors: [
                                                            Colors
                                                                .grey
                                                                .shade400,
                                                            Colors
                                                                .grey
                                                                .shade600,
                                                          ],
                                                        )
                                                        : AppTheme.primaryGradient(
                                                          isDark,
                                                        )),
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                          child: Material(
                                            color: Colors.transparent,
                                            child: InkWell(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              onTap:
                                                  _isPhoneVerified ||
                                                          _isSendingOtp
                                                      ? null
                                                      : _verifyPhoneNumber,
                                              child: Padding(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 16.0,
                                                    ),
                                                child: Center(
                                                  child:
                                                      _isSendingOtp
                                                          ? const SizedBox(
                                                            width: 16,
                                                            height: 16,
                                                            child: CircularProgressIndicator(
                                                              strokeWidth: 2,
                                                              valueColor:
                                                                  AlwaysStoppedAnimation<
                                                                    Color
                                                                  >(
                                                                    Colors
                                                                        .white,
                                                                  ),
                                                            ),
                                                          )
                                                          : Text(
                                                            _isPhoneVerified
                                                                ? 'Verified'
                                                                : 'Verify',
                                                            style:
                                                                const TextStyle(
                                                                  color:
                                                                      Colors
                                                                          .white,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w600,
                                                                  fontSize: 14,
                                                                ),
                                                          ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                if (_phoneError != null)
                                  Padding(
                                    padding: const EdgeInsets.only(
                                      top: 8.0,
                                      left: 12.0,
                                    ),
                                    child: Text(
                                      _phoneError!,
                                      style: const TextStyle(
                                        color: Colors.red,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),

                        // Error message
                        if (authProvider.errorMessage != null)
                          Container(
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
                                    isDark
                                        ? Color(0xFF222f43)
                                        : Color(0xFFe5e5e5),
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
                                  child: const Icon(
                                    Icons.error_outline,
                                    color: Colors.red,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    authProvider.errorMessage!,
                                    style: TextStyle(
                                      color: Colors.red.shade300,
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                        const SizedBox(height: 24),

                        // Sign up button
                        GradientButton(
                          text: 'Create Account',
                          onPressed: _signUp,
                          isLoading: authProvider.status == AuthStatus.loading,
                        ),

                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
