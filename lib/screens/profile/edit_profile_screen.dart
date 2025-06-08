import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/user_model.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/gradient_button.dart';
import '../../utils/app_theme.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({Key? key}) : super(key: key);

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneNumberController = TextEditingController();

  // Student-specific controllers
  final _studentNumberController = TextEditingController();
  final _institutionController = TextEditingController();
  final _levelController = TextEditingController();

  // Lecturer-specific controllers
  final _staffIdController = TextEditingController();
  final _departmentController = TextEditingController();

  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initializeFields();
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _phoneNumberController.dispose();
    _studentNumberController.dispose();
    _institutionController.dispose();
    _levelController.dispose();
    _staffIdController.dispose();
    _departmentController.dispose();
    super.dispose();
  }

  void _initializeFields() {
    final user = Provider.of<AuthProvider>(context, listen: false).currentUser;
    if (user == null) return;

    _fullNameController.text = user.fullName;
    _emailController.text = user.email;
    _phoneNumberController.text = user.phoneNumber ?? '';

    if (user is Student) {
      _studentNumberController.text = user.studentNumber;
      _institutionController.text = user.institution;
      _levelController.text = user.level;
    } else if (user is Lecturer) {
      _staffIdController.text = user.staffId;
      _departmentController.text = user.department;
    }
  }

  Future<void> _updateProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final user = authProvider.currentUser;
      if (user == null) return;

      final phoneNumber =
          _phoneNumberController.text.trim().isNotEmpty
              ? _phoneNumberController.text.trim()
              : null;

      if (user is Student) {
        await authProvider.updateStudentProfile(
          fullName: _fullNameController.text.trim(),
          studentNumber: _studentNumberController.text.trim(),
          institution: _institutionController.text.trim(),
          level: _levelController.text.trim(),
          phoneNumber: phoneNumber,
        );
      } else if (user is Lecturer) {
        await authProvider.updateLecturerProfile(
          fullName: _fullNameController.text.trim(),
          staffId: _staffIdController.text.trim(),
          department: _departmentController.text.trim(),
          phoneNumber: phoneNumber,
        );
      }

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isLecturer = Provider.of<AuthProvider>(context).isLecturer;

    return Scaffold(
      appBar: AppBar(title: const Text('Edit Profile'), elevation: 0),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Profile image with gradient border
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient:
                          isLecturer
                              ? AppTheme.secondaryGradient(isDark)
                              : AppTheme.primaryGradient(isDark),
                    ),
                    child: CircleAvatar(
                      radius: 50,
                      backgroundColor:
                          isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
                      child: Icon(
                        Icons.person,
                        size: 50,
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
                ),

                const SizedBox(height: 24),

                // Common fields
                CustomTextField(
                  controller: _fullNameController,
                  labelText: 'Full Name',
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your full name';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 16),

                CustomTextField(
                  controller: _emailController,
                  labelText: 'Email',
                  enabled: false, // Email cannot be changed
                ),

                const SizedBox(height: 16),

                CustomTextField(
                  controller: _phoneNumberController,
                  labelText: 'Phone Number (for SMS notifications)',
                  keyboardType: TextInputType.phone,
                  validator: (value) {
                    if (value != null && value.isNotEmpty) {
                      // Basic phone number validation - can be improved
                      if (!RegExp(r'^\+?[0-9]{10,15}$').hasMatch(value)) {
                        return 'Please enter a valid phone number';
                      }
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 16),

                // Role-specific fields
                if (isLecturer) ...[
                  CustomTextField(
                    controller: _staffIdController,
                    labelText: 'Staff ID',
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your staff ID';
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: 16),

                  CustomTextField(
                    controller: _departmentController,
                    labelText: 'Department',
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your department';
                      }
                      return null;
                    },
                  ),
                ] else ...[
                  CustomTextField(
                    controller: _studentNumberController,
                    labelText: 'Student Number',
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your student number';
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: 16),

                  CustomTextField(
                    controller: _institutionController,
                    labelText: 'Institution',
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your institution';
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: 16),

                  CustomTextField(
                    controller: _levelController,
                    labelText: 'Level',
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your level';
                      }
                      return null;
                    },
                  ),
                ],

                const SizedBox(height: 24),

                if (_errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(color: Colors.red, fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                  ),

                GradientButton(
                  text: 'Save Changes',
                  onPressed: _updateProfile,
                  isLoading: _isLoading,
                  useSecondaryGradient: isLecturer,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
