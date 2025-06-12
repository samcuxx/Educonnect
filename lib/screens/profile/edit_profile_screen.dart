import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
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
  File? _profileImage;
  final ImagePicker _imagePicker = ImagePicker();

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

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 80,
      );

      if (image != null) {
        setState(() {
          _profileImage = File(image.path);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to pick image: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _removeImage() async {
    setState(() {
      _profileImage = null;
    });
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
          profileImage: _profileImage,
        );
      } else if (user is Lecturer) {
        await authProvider.updateLecturerProfile(
          fullName: _fullNameController.text.trim(),
          staffId: _staffIdController.text.trim(),
          department: _departmentController.text.trim(),
          phoneNumber: phoneNumber,
          profileImage: _profileImage,
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
      appBar: AppBar(
        title: Text(
          'Edit Profile',
          style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 18),
        ),
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Profile image with gradient border and edit capability
                Center(
                  child: Stack(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient:
                              isLecturer
                                  ? AppTheme.secondaryGradient(isDark)
                                  : AppTheme.primaryGradient(isDark),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(46),
                          child: Container(
                            width: 92,
                            height: 92,
                            color:
                                isDark
                                    ? AppTheme.darkSurface
                                    : AppTheme.lightSurface,
                            child:
                                _profileImage != null
                                    ? Image.file(
                                      _profileImage!,
                                      width: 92,
                                      height: 92,
                                      fit: BoxFit.cover,
                                    )
                                    : (Provider.of<AuthProvider>(
                                              context,
                                            ).currentUser?.profileImageUrl !=
                                            null
                                        ? CachedNetworkImage(
                                          imageUrl:
                                              Provider.of<AuthProvider>(
                                                context,
                                              ).currentUser!.profileImageUrl!,
                                          width: 92,
                                          height: 92,
                                          fit: BoxFit.cover,
                                          placeholder:
                                              (context, url) => Center(
                                                child: CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                  valueColor: AlwaysStoppedAnimation<
                                                    Color
                                                  >(
                                                    isLecturer
                                                        ? (isDark
                                                            ? AppTheme
                                                                .darkSecondaryStart
                                                            : AppTheme
                                                                .lightSecondaryStart)
                                                        : (isDark
                                                            ? AppTheme
                                                                .darkPrimaryStart
                                                            : AppTheme
                                                                .lightPrimaryStart),
                                                  ),
                                                ),
                                              ),
                                          errorWidget:
                                              (context, url, error) => Icon(
                                                Icons.person_outline_rounded,
                                                size: 50,
                                                color:
                                                    isLecturer
                                                        ? (isDark
                                                            ? AppTheme
                                                                .darkSecondaryStart
                                                            : AppTheme
                                                                .lightSecondaryStart)
                                                        : (isDark
                                                            ? AppTheme
                                                                .darkPrimaryStart
                                                            : AppTheme
                                                                .lightPrimaryStart),
                                              ),
                                          cacheKey:
                                              'profile_edit_${Provider.of<AuthProvider>(context).currentUser!.profileImageUrl!.hashCode}',
                                        )
                                        : Icon(
                                          Icons.person_outline_rounded,
                                          size: 50,
                                          color:
                                              isLecturer
                                                  ? (isDark
                                                      ? AppTheme
                                                          .darkSecondaryStart
                                                      : AppTheme
                                                          .lightSecondaryStart)
                                                  : (isDark
                                                      ? AppTheme
                                                          .darkPrimaryStart
                                                      : AppTheme
                                                          .lightPrimaryStart),
                                        )),
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          decoration: BoxDecoration(
                            color:
                                isLecturer
                                    ? (isDark
                                        ? AppTheme.darkSecondaryStart
                                        : AppTheme.lightSecondaryStart)
                                    : (isDark
                                        ? AppTheme.darkPrimaryStart
                                        : AppTheme.lightPrimaryStart),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color:
                                  isDark
                                      ? AppTheme.darkSurface
                                      : AppTheme.lightSurface,
                              width: 2,
                            ),
                          ),
                          child: PopupMenuButton<String>(
                            icon: const Icon(
                              Icons.camera_alt,
                              color: Colors.white,
                              size: 16,
                            ),
                            onSelected: (value) {
                              if (value == 'camera') {
                                _pickImage();
                              } else if (value == 'remove') {
                                _removeImage();
                              }
                            },
                            itemBuilder:
                                (context) => [
                                  const PopupMenuItem(
                                    value: 'camera',
                                    child: Row(
                                      children: [
                                        Icon(Icons.photo_library),
                                        SizedBox(width: 8),
                                        Text('Choose from Gallery'),
                                      ],
                                    ),
                                  ),
                                  if (_profileImage != null ||
                                      Provider.of<AuthProvider>(
                                            context,
                                            listen: false,
                                          ).currentUser?.profileImageUrl !=
                                          null)
                                    const PopupMenuItem(
                                      value: 'remove',
                                      child: Row(
                                        children: [
                                          Icon(Icons.delete, color: Colors.red),
                                          SizedBox(width: 8),
                                          Text(
                                            'Remove Photo',
                                            style: TextStyle(color: Colors.red),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 28),

                Text(
                  'Personal Information',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color:
                        isDark
                            ? AppTheme.darkTextPrimary
                            : AppTheme.lightTextPrimary,
                  ),
                ),

                const SizedBox(height: 20),

                // Common fields
                CustomTextField(
                  controller: _fullNameController,
                  labelText: 'Full Name',
                  prefixIcon: const Icon(Icons.person_outline_rounded),
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
                  prefixIcon: const Icon(Icons.email_outlined),
                  enabled: false, // Email cannot be changed
                ),

                const SizedBox(height: 16),

                CustomTextField(
                  controller: _phoneNumberController,
                  labelText: 'Phone Number',
                  hintText: 'For SMS notifications',
                  prefixIcon: const Icon(Icons.phone_outlined),
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

                const SizedBox(height: 24),

                // Role-specific section header
                Text(
                  isLecturer ? 'Academic Information' : 'Student Information',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color:
                        isDark
                            ? AppTheme.darkTextPrimary
                            : AppTheme.lightTextPrimary,
                  ),
                ),

                const SizedBox(height: 20),

                // Role-specific fields
                if (isLecturer) ...[
                  CustomTextField(
                    controller: _staffIdController,
                    labelText: 'Staff ID',
                    prefixIcon: const Icon(Icons.badge_outlined),
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
                    prefixIcon: const Icon(Icons.business_outlined),
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
                    prefixIcon: const Icon(Icons.numbers_outlined),
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
                    prefixIcon: const Icon(Icons.business_outlined),
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
                    prefixIcon: const Icon(Icons.school_outlined),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your level';
                      }
                      return null;
                    },
                  ),
                ],

                const SizedBox(height: 28),

                if (_errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(
                      _errorMessage!,
                      style: GoogleFonts.inter(
                        color: Colors.red,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
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
