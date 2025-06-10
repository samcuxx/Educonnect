import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../models/class_model.dart';
import '../../utils/app_theme.dart';
import '../../utils/dialog_utils.dart';

class ClassDetailsUtils {
  // Show class details in a bottom sheet
  static void showClassDetails(
    BuildContext context,
    ClassModel classModel,
    int studentsCount,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    DialogUtils.showDetailsBottomSheet(
      context: context,
      title: classModel.name,
      subtitle: classModel.courseCode,
      icon: Icons.class_,
      content: Column(
        children: [
          _buildDetailRow(
            context,
            icon: Icons.school,
            label: 'Level',
            value: classModel.level,
            isDark: isDark,
          ),
          const SizedBox(height: 16),
          _buildDetailRow(
            context,
            icon: Icons.people,
            label: 'Students',
            value: '$studentsCount enrolled',
            isDark: isDark,
          ),
          const SizedBox(height: 16),
          _buildDetailRow(
            context,
            icon: Icons.calendar_today,
            label: 'Created',
            value: DateFormat('MMMM d, yyyy').format(classModel.createdAt),
            isDark: isDark,
          ),
          if (classModel.code != null) ...[
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: (isDark ? AppTheme.darkSurface : Colors.white),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.key,
                    color:
                        isDark
                            ? AppTheme.darkSecondaryStart
                            : AppTheme.lightSecondaryStart,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Class Code',
                          style: GoogleFonts.inter(
                            color:
                                isDark
                                    ? AppTheme.darkTextSecondary
                                    : AppTheme.lightTextSecondary,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 4),
                        ShaderMask(
                          shaderCallback:
                              (bounds) => LinearGradient(
                                colors:
                                    isDark
                                        ? [
                                          AppTheme.darkSecondaryStart,
                                          AppTheme.darkSecondaryEnd,
                                        ]
                                        : [
                                          AppTheme.lightSecondaryStart,
                                          AppTheme.lightSecondaryEnd,
                                        ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ).createShader(bounds),
                          child: Text(
                            classModel.code!,
                            style: GoogleFonts.inter(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy),
                    color:
                        isDark
                            ? AppTheme.darkSecondaryStart
                            : AppTheme.lightSecondaryStart,
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: classModel.code!));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Class code copied to clipboard'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // Helper method to build detail rows
  static Widget _buildDetailRow(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    required bool isDark,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: (isDark
                    ? AppTheme.darkSecondaryStart
                    : AppTheme.lightSecondaryStart)
                .withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: (isDark
                      ? AppTheme.darkSecondaryStart
                      : AppTheme.lightSecondaryStart)
                  .withOpacity(0.2),
            ),
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
                  color:
                      isDark
                          ? AppTheme.darkTextSecondary
                          : AppTheme.lightTextSecondary,
                  fontSize: 12,
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
    );
  }
}
