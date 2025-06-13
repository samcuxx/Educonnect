import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/student_management_model.dart';
import '../providers/student_management_provider.dart';
import '../utils/app_theme.dart';
import '../utils/dialog_utils.dart';
import 'student_avatar.dart';
import 'gradient_container.dart';

class StudentDetailCard extends StatelessWidget {
  final ManagedStudentModel student;

  const StudentDetailCard({Key? key, required this.student}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final size = MediaQuery.of(context).size;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      elevation: 0,
      child: Container(
        width: size.width,
        constraints: BoxConstraints(
          maxWidth: 500,
          maxHeight: size.height * 0.8,
        ),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              spreadRadius: 1,
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header with profile image
              GradientContainer(
                useSecondaryGradient: true,
                padding: EdgeInsets.zero,
                borderRadius: 0,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Background design elements
                    Positioned(
                      right: -20,
                      top: -20,
                      child: Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    Positioned(
                      left: -30,
                      bottom: -30,
                      child: Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.08),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),

                    // Content
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 30, 20, 30),
                      child: Column(
                        children: [
                          StudentAvatar(
                            imageUrl: student.profileImageUrl,
                            name: student.fullName,
                            radius: 40,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            student.fullName,
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              student.studentNumber,
                              style: GoogleFonts.inter(
                                color: Colors.white.withOpacity(0.9),
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Close button
                    Positioned(
                      top: 12,
                      right: 12,
                      child: IconButton(
                        icon: const Icon(
                          Icons.close_rounded,
                          color: Colors.white,
                        ),
                        onPressed: () => Navigator.pop(context),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.white.withOpacity(0.2),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Student details
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Text(
                          'Student Information',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color:
                                isDark
                                    ? AppTheme.darkTextPrimary
                                    : AppTheme.lightTextPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildDetailItem(
                        icon: Icons.email_outlined,
                        label: 'Email Address',
                        value: student.email,
                        isDark: isDark,
                      ),
                      _buildDivider(isDark),
                      _buildDetailItem(
                        icon: Icons.school_outlined,
                        label: 'Institution',
                        value: student.institution,
                        isDark: isDark,
                      ),
                      _buildDivider(isDark),
                      _buildDetailItem(
                        icon: Icons.grade_outlined,
                        label: 'Education Level',
                        value: student.level,
                        isDark: isDark,
                      ),
                      _buildDivider(isDark),
                      _buildDetailItem(
                        icon: Icons.phone_outlined,
                        label: 'Phone Number',
                        value: student.phoneNumber ?? 'Not provided',
                        isDark: isDark,
                      ),
                      _buildDivider(isDark),
                      _buildDetailItem(
                        icon: Icons.calendar_today_outlined,
                        label: 'Joined Class On',
                        value: student.joinedAtFormatted,
                        isDark: isDark,
                      ),
                    ],
                  ),
                ),
              ),

              // Action button
              Container(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, -5),
                    ),
                  ],
                ),
                child: ElevatedButton.icon(
                  onPressed: () {
                    // Get references before closing the dialog
                    final scaffoldMessenger = ScaffoldMessenger.of(context);
                    final studentProvider =
                        Provider.of<StudentManagementProvider>(
                          context,
                          listen: false,
                        );
                    final studentName = student.fullName;
                    final studentId = student.membershipId;

                    // Close the dialog
                    Navigator.pop(context);

                    DialogUtils.showConfirmationDialog(
                      context: context,
                      title: 'Remove Student',
                      message:
                          'Are you sure you want to remove $studentName from this class?',
                      confirmButtonText: 'Remove',
                      isDangerous: true,
                    ).then((confirmed) {
                      if (confirmed) {
                        // Show loading indicator
                        scaffoldMessenger.showSnackBar(
                          SnackBar(
                            content: Row(
                              children: [
                                const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Text('Removing $studentName...'),
                              ],
                            ),
                            duration: const Duration(seconds: 60),
                          ),
                        );

                        // Remove student from class
                        studentProvider
                            .removeStudentFromClass(studentId)
                            .then((_) {
                              // Show success message
                              scaffoldMessenger.hideCurrentSnackBar();
                              scaffoldMessenger.showSnackBar(
                                SnackBar(
                                  content: Text(
                                    '$studentName has been removed from the class',
                                  ),
                                  backgroundColor: Colors.green,
                                  duration: const Duration(seconds: 3),
                                ),
                              );
                            })
                            .catchError((error) {
                              // Show error message
                              scaffoldMessenger.hideCurrentSnackBar();
                              scaffoldMessenger.showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Failed to remove student: ${error.toString()}',
                                  ),
                                  backgroundColor: Colors.red,
                                  duration: const Duration(seconds: 3),
                                ),
                              );
                            });
                      }
                    });
                  },
                  icon: const Icon(Icons.person_remove_rounded),
                  label: Text(
                    'Remove From Class',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                    minimumSize: const Size(double.infinity, 56),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailItem({
    required IconData icon,
    required String label,
    required String value,
    required bool isDark,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color:
                  isDark
                      ? AppTheme.darkSecondaryStart.withOpacity(0.2)
                      : AppTheme.lightSecondaryStart.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              size: 20,
              color:
                  isDark
                      ? AppTheme.darkSecondaryStart
                      : AppTheme.lightSecondaryStart,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color:
                        isDark
                            ? AppTheme.darkTextSecondary
                            : AppTheme.lightTextSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
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
      ),
    );
  }

  Widget _buildDivider(bool isDark) {
    return Divider(
      color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
      height: 1,
      thickness: 1,
      indent: 56,
      endIndent: 20,
    );
  }
}
