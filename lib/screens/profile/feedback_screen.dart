import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../utils/app_theme.dart';
import '../../widgets/gradient_button.dart';

class FeedbackScreen extends StatefulWidget {
  const FeedbackScreen({Key? key}) : super(key: key);

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  final _formKey = GlobalKey<FormState>();
  final _feedbackController = TextEditingController();
  String _selectedCategory = 'General';
  bool _isSubmitting = false;
  bool _submitted = false;

  final List<String> _categories = [
    'General',
    'Bug Report',
    'Feature Request',
    'Performance Issue',
    'User Experience',
    'Other',
  ];

  @override
  void dispose() {
    _feedbackController.dispose();
    super.dispose();
  }

  void _submitFeedback() {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isSubmitting = true;
      });

      // Simulate API call
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          setState(() {
            _isSubmitting = false;
            _submitted = true;
          });
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isLecturer = false; // Get this from provider if needed

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Send Feedback',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold),
        ),
        backgroundColor: isDark ? AppTheme.darkSurface : Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child:
            _submitted
                ? _buildSuccessView(isDark, isLecturer)
                : _buildFeedbackForm(isDark, isLecturer),
      ),
    );
  }

  Widget _buildSuccessView(bool isDark, bool isLecturer) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle_outline,
                color: Colors.green,
                size: 64,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Thank You!',
              style: GoogleFonts.inter(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color:
                    isDark
                        ? AppTheme.darkTextPrimary
                        : AppTheme.lightTextPrimary,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Your feedback has been submitted successfully. We appreciate your input and will use it to improve the app.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 16,
                color:
                    isDark
                        ? AppTheme.darkTextSecondary
                        : AppTheme.lightTextSecondary,
              ),
            ),
            const SizedBox(height: 32),
            GradientButton(
              text: 'Back to Profile',
              onPressed: () {
                Navigator.pop(context);
              },
              useSecondaryGradient: isLecturer,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeedbackForm(bool isDark, bool isLecturer) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Intro text
            Text(
              'We Value Your Feedback',
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color:
                    isDark
                        ? AppTheme.darkTextPrimary
                        : AppTheme.lightTextPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Help us improve EduConnect by sharing your thoughts and suggestions. Your feedback is important to us!',
              style: GoogleFonts.inter(
                fontSize: 14,
                color:
                    isDark
                        ? AppTheme.darkTextSecondary
                        : AppTheme.lightTextSecondary,
              ),
            ),
            const SizedBox(height: 32),

            // Category dropdown
            Text(
              'Feedback Category',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w600,
                color:
                    isDark
                        ? AppTheme.darkTextPrimary
                        : AppTheme.lightTextPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
                ),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedCategory,
                  isExpanded: true,
                  icon: Icon(
                    Icons.arrow_drop_down,
                    color:
                        isDark
                            ? AppTheme.darkTextSecondary
                            : AppTheme.lightTextSecondary,
                  ),
                  style: GoogleFonts.inter(
                    color:
                        isDark
                            ? AppTheme.darkTextPrimary
                            : AppTheme.lightTextPrimary,
                  ),
                  dropdownColor:
                      isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
                  items:
                      _categories.map((String category) {
                        return DropdownMenuItem<String>(
                          value: category,
                          child: Text(category),
                        );
                      }).toList(),
                  onChanged: (String? newValue) {
                    if (newValue != null) {
                      setState(() {
                        _selectedCategory = newValue;
                      });
                    }
                  },
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Feedback text field
            Text(
              'Your Feedback',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w600,
                color:
                    isDark
                        ? AppTheme.darkTextPrimary
                        : AppTheme.lightTextPrimary,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _feedbackController,
              maxLines: 8,
              decoration: InputDecoration(
                hintText: 'Write your feedback here...',
                hintStyle: GoogleFonts.inter(
                  color:
                      isDark
                          ? AppTheme.darkTextSecondary.withOpacity(0.5)
                          : AppTheme.lightTextSecondary.withOpacity(0.5),
                ),
                filled: true,
                fillColor:
                    isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(28),
                  borderSide: BorderSide(
                    color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(28),
                  borderSide: BorderSide(
                    color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(28),
                  borderSide: BorderSide(
                    color:
                        isLecturer
                            ? (isDark
                                ? AppTheme.darkSecondaryStart
                                : AppTheme.lightSecondaryStart)
                            : (isDark
                                ? AppTheme.darkPrimaryStart
                                : AppTheme.lightPrimaryStart),
                    width: 2,
                  ),
                ),
                contentPadding: const EdgeInsets.all(20),
              ),
              style: GoogleFonts.inter(
                color:
                    isDark
                        ? AppTheme.darkTextPrimary
                        : AppTheme.lightTextPrimary,
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter your feedback';
                }
                if (value.trim().length < 10) {
                  return 'Feedback must be at least 10 characters';
                }
                return null;
              },
            ),

            const SizedBox(height: 32),

            // Submit button
            SizedBox(
              width: double.infinity,
              child: GradientButton(
                text: 'Submit Feedback',
                onPressed: _isSubmitting ? () {} : _submitFeedback,
                isLoading: _isSubmitting,
                useSecondaryGradient: isLecturer,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
