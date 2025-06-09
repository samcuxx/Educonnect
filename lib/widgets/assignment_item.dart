import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/assignment_model.dart';
import '../utils/app_theme.dart';
import '../utils/file_utils.dart';

class AssignmentItem extends StatelessWidget {
  final AssignmentModel assignment;
  final String className;
  final String courseCode;
  final bool isLecturer;
  final bool? hasSubmitted;
  final VoidCallback? onSubmit;
  final VoidCallback? onViewSubmissions;
  final VoidCallback? onDelete;

  const AssignmentItem({
    Key? key,
    required this.assignment,
    required this.className,
    required this.courseCode,
    required this.isLecturer,
    this.hasSubmitted,
    this.onSubmit,
    this.onViewSubmissions,
    this.onDelete,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isOverdue = assignment.deadline.isBefore(DateTime.now());
    final daysUntilDeadline =
        assignment.deadline.difference(DateTime.now()).inDays;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _getBorderColor(isDark, isOverdue, daysUntilDeadline),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.1 : 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap:
              assignment.fileUrl != null
                  ? () => _openAssignment(context)
                  : null,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with assignment icon and actions
                Row(
                  children: [
                    // Assignment type icon
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        gradient:
                            isLecturer
                                ? AppTheme.secondaryGradient(isDark)
                                : AppTheme.primaryGradient(isDark),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        assignment.fileUrl != null
                            ? FileUtils.getFileIcon(assignment.fileUrl!)
                            : Icons.assignment,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Title and metadata
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            assignment.title,
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.bold),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$courseCode • $className',
                            style: Theme.of(
                              context,
                            ).textTheme.bodySmall?.copyWith(
                              color:
                                  isDark
                                      ? AppTheme.darkTextSecondary
                                      : AppTheme.lightTextSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Actions menu
                    if (isLecturer)
                      PopupMenuButton<String>(
                        icon: Icon(
                          Icons.more_vert,
                          color:
                              isDark
                                  ? AppTheme.darkTextSecondary
                                  : AppTheme.lightTextSecondary,
                        ),
                        onSelected: (value) => _handleAction(context, value),
                        itemBuilder:
                            (context) => [
                              if (assignment.fileUrl != null)
                                const PopupMenuItem(
                                  value: 'download',
                                  child: Row(
                                    children: [
                                      Icon(Icons.download, size: 18),
                                      SizedBox(width: 8),
                                      Text('Download'),
                                    ],
                                  ),
                                ),
                              const PopupMenuItem(
                                value: 'submissions',
                                child: Row(
                                  children: [
                                    Icon(Icons.upload_file, size: 18),
                                    SizedBox(width: 8),
                                    Text('View Submissions'),
                                  ],
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'delete',
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.delete,
                                      size: 18,
                                      color: Colors.red,
                                    ),
                                    SizedBox(width: 8),
                                    Text(
                                      'Delete',
                                      style: TextStyle(color: Colors.red),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                      )
                    else
                      _buildStudentActions(context, isDark, isOverdue),
                  ],
                ),

                // Description (if available)
                if (assignment.description?.isNotEmpty == true) ...[
                  const SizedBox(height: 12),
                  Text(
                    assignment.description!,
                    style: Theme.of(context).textTheme.bodySmall,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],

                const SizedBox(height: 12),

                // Assignment details
                Row(
                  children: [
                    // File type badge (if has attachment)
                    if (assignment.fileUrl != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: (isLecturer
                                  ? (isDark
                                      ? AppTheme.darkSecondaryStart
                                      : AppTheme.lightSecondaryStart)
                                  : (isDark
                                      ? AppTheme.darkPrimaryStart
                                      : AppTheme.lightPrimaryStart))
                              .withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.attach_file,
                              size: 12,
                              color:
                                  isLecturer
                                      ? (isDark
                                          ? AppTheme.darkSecondaryStart
                                          : AppTheme.lightSecondaryStart)
                                      : (isDark
                                          ? AppTheme.darkPrimaryStart
                                          : AppTheme.lightPrimaryStart),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              FileUtils.getFileType(assignment.fileUrl!),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
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
                          ],
                        ),
                      ),

                    const Spacer(),

                    // Assignment info
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'by ${assignment.assignedByName}',
                          style: Theme.of(
                            context,
                          ).textTheme.bodySmall?.copyWith(
                            color:
                                isDark
                                    ? AppTheme.darkTextSecondary
                                    : AppTheme.lightTextSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Due: ${FileUtils.formatDateTime(assignment.deadline)}',
                          style: Theme.of(
                            context,
                          ).textTheme.bodySmall?.copyWith(
                            color: _getDeadlineColor(
                              isDark,
                              isOverdue,
                              daysUntilDeadline,
                            ),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                // Submission status for students
                if (!isLecturer) ...[
                  const SizedBox(height: 12),
                  _buildSubmissionStatus(context, isDark, isOverdue),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStudentActions(
    BuildContext context,
    bool isDark,
    bool isOverdue,
  ) {
    if (hasSubmitted == true) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.green.withOpacity(0.1),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle, size: 16, color: Colors.green[600]),
            const SizedBox(width: 4),
            Text(
              'Submitted',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.green[600],
              ),
            ),
          ],
        ),
      );
    } else if (isOverdue) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.1),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.warning, size: 16, color: Colors.red[600]),
            const SizedBox(width: 4),
            Text(
              'Overdue',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.red[600],
              ),
            ),
          ],
        ),
      );
    } else {
      return ElevatedButton.icon(
        onPressed: onSubmit,
        icon: const Icon(Icons.upload, size: 16),
        label: const Text('Submit'),
        style: ElevatedButton.styleFrom(
          backgroundColor:
              isDark ? AppTheme.darkPrimaryStart : AppTheme.lightPrimaryStart,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      );
    }
  }

  Widget _buildSubmissionStatus(
    BuildContext context,
    bool isDark,
    bool isOverdue,
  ) {
    if (hasSubmitted == true) {
      return Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.green.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.green.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green[600], size: 16),
            const SizedBox(width: 8),
            Text(
              'Assignment submitted successfully',
              style: TextStyle(
                color: Colors.green[600],
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    } else if (isOverdue) {
      return Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.red.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Icon(Icons.warning, color: Colors.red[600], size: 16),
            const SizedBox(width: 8),
            Text(
              'Assignment is overdue',
              style: TextStyle(
                color: Colors.red[600],
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    } else {
      final daysLeft = assignment.deadline.difference(DateTime.now()).inDays;
      final color =
          daysLeft <= 1
              ? Colors.orange
              : (isDark
                  ? AppTheme.darkPrimaryStart
                  : AppTheme.lightPrimaryStart);

      return Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Icon(
              daysLeft <= 1 ? Icons.schedule : Icons.info,
              color: color,
              size: 16,
            ),
            const SizedBox(width: 8),
            Text(
              daysLeft <= 1
                  ? 'Due ${daysLeft == 0 ? "today" : "tomorrow"}'
                  : 'Due in $daysLeft days',
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }
  }

  Color _getBorderColor(bool isDark, bool isOverdue, int daysUntilDeadline) {
    if (hasSubmitted == true) {
      return Colors.green.withOpacity(0.5);
    } else if (isOverdue) {
      return Colors.red.withOpacity(0.5);
    } else if (daysUntilDeadline <= 1) {
      return Colors.orange.withOpacity(0.5);
    } else {
      return (isDark ? Colors.grey[800] : Colors.grey[200])!;
    }
  }

  Color _getDeadlineColor(bool isDark, bool isOverdue, int daysUntilDeadline) {
    if (isOverdue) {
      return Colors.red[600]!;
    } else if (daysUntilDeadline <= 1) {
      return Colors.orange[600]!;
    } else {
      return isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary;
    }
  }

  void _handleAction(BuildContext context, String action) {
    switch (action) {
      case 'download':
        if (assignment.fileUrl != null) {
          _openAssignment(context);
        }
        break;
      case 'submissions':
        onViewSubmissions?.call();
        break;
      case 'delete':
        _showDeleteConfirmation(context);
        break;
    }
  }

  void _openAssignment(BuildContext context) async {
    if (assignment.fileUrl == null) return;

    try {
      final uri = Uri.parse(assignment.fileUrl!);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Cannot open assignment: ${assignment.title}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error opening assignment: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showDeleteConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Delete Assignment'),
            content: Text(
              'Are you sure you want to delete "${assignment.title}"?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  onDelete?.call();
                },
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Delete'),
              ),
            ],
          ),
    );
  }
}
