import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/assignment_model.dart';
import '../../models/class_model.dart';
import '../../providers/auth_provider.dart';
import '../../utils/app_theme.dart';
import '../../utils/dialog_utils.dart';
import '../../utils/file_utils.dart';
import '../submissions_screen.dart';

class AssignmentsTab extends StatefulWidget {
  final ClassModel classModel;
  final List<AssignmentModel> assignments;
  final Map<String, bool> assignmentSubmissions;
  final bool isLoading;
  final Map<String, double> downloadProgress;
  final Map<String, String> downloadedFiles;
  final Function() onRefresh;
  final Function(AssignmentModel) onDelete;
  final Function(AssignmentModel) onDownload;
  final Function(AssignmentModel) onOpen;
  final Function(AssignmentModel) onSubmit;
  final Function(AssignmentModel) onViewSubmissions;
  final Function() onCreateAssignment;
  final bool isOffline;

  const AssignmentsTab({
    Key? key,
    required this.classModel,
    required this.assignments,
    required this.assignmentSubmissions,
    required this.isLoading,
    required this.downloadProgress,
    required this.downloadedFiles,
    required this.onRefresh,
    required this.onDelete,
    required this.onDownload,
    required this.onOpen,
    required this.onSubmit,
    required this.onViewSubmissions,
    required this.onCreateAssignment,
    this.isOffline = false,
  }) : super(key: key);

  @override
  State<AssignmentsTab> createState() => _AssignmentsTabState();
}

class _AssignmentsTabState extends State<AssignmentsTab> {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isLecturer = Provider.of<AuthProvider>(context).isLecturer;

    return RefreshIndicator(
      onRefresh: () async => widget.onRefresh(),
      displacement: 40.0,
      color:
          isDark ? AppTheme.darkSecondaryStart : AppTheme.lightSecondaryStart,
      backgroundColor: isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
      strokeWidth: 3.0,
      child: Column(
        children: [
          if (widget.isOffline)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
              color: Colors.orange.withOpacity(0.1),
              child: Row(
                children: [
                  Icon(Icons.offline_bolt, size: 16, color: Colors.orange),
                  const SizedBox(width: 8),
                  Text(
                    'Offline Mode - Showing cached data',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.orange[800],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child:
                widget.isLoading && widget.assignments.isEmpty
                    ? Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(
                          isDark
                              ? AppTheme.darkSecondaryStart
                              : AppTheme.lightSecondaryStart,
                        ),
                      ),
                    )
                    : widget.assignments.isEmpty
                    ? _buildEmptyState(
                      context,
                      icon: Icons.assignment_outlined,
                      title: 'No assignments yet',
                      message:
                          isLecturer
                              ? 'Tap + to create an assignment for your students'
                              : 'Your lecturer has not posted any assignments yet',
                    )
                    : ListView.builder(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      itemCount: widget.assignments.length,
                      itemBuilder: (context, index) {
                        final assignment = widget.assignments[index];
                        return _buildAssignmentItem(
                          context,
                          assignment,
                          isLecturer,
                        );
                      },
                    ),
          ),
        ],
      ),
    );
  }

  Widget _buildAssignmentItem(
    BuildContext context,
    AssignmentModel assignment,
    bool isLecturer,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bool hasSubmitted =
        widget.assignmentSubmissions[assignment.id] ?? false;
    final bool isDownloading = widget.downloadProgress.containsKey(
      assignment.id,
    );
    final bool isDownloaded = widget.downloadedFiles.containsKey(assignment.id);
    final bool isOverdue = DateTime.now().isAfter(assignment.deadline);
    final bool isUpcoming =
        !isOverdue &&
        DateTime.now().difference(assignment.deadline).inDays > -3;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => isLecturer ? widget.onViewSubmissions(assignment) : null,
          onLongPress:
              isLecturer ? () => _showAssignmentOptions(assignment) : null,
          borderRadius: BorderRadius.circular(28),
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? AppTheme.darkSurface : Colors.white,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color:
                    isOverdue && !isLecturer && !hasSubmitted
                        ? Colors.red.withOpacity(0.3)
                        : isDark
                        ? AppTheme.darkBorder
                        : AppTheme.lightBorder,
              ),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: (isOverdue && !hasSubmitted
                                ? Colors.red
                                : isUpcoming
                                ? Colors.orange
                                : isDark
                                ? AppTheme.darkPrimaryStart
                                : AppTheme.lightPrimaryStart)
                            .withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        isOverdue && !hasSubmitted
                            ? Icons.warning_rounded
                            : isUpcoming
                            ? Icons.timer
                            : Icons.assignment_outlined,
                        color:
                            isOverdue && !hasSubmitted
                                ? Colors.red
                                : isUpcoming
                                ? Colors.orange
                                : isDark
                                ? AppTheme.darkPrimaryStart
                                : AppTheme.lightPrimaryStart,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            assignment.title,
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color:
                                  isDark
                                      ? AppTheme.darkTextPrimary
                                      : AppTheme.lightTextPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Due ${DateFormat('MMM d, yyyy • h:mm a').format(assignment.deadline)}',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color:
                                  isOverdue && !hasSubmitted && !isLecturer
                                      ? Colors.red
                                      : isDark
                                      ? AppTheme.darkTextSecondary
                                      : AppTheme.lightTextSecondary,
                              fontWeight:
                                  isOverdue && !hasSubmitted && !isLecturer
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!isLecturer && hasSubmitted)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.green.withOpacity(0.3),
                          ),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.check_circle,
                              color: Colors.green,
                              size: 14,
                            ),
                            SizedBox(width: 4),
                            Text(
                              'Submitted',
                              style: TextStyle(
                                color: Colors.green,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                if (assignment.description != null &&
                    assignment.description!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    assignment.description!,
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? Colors.white70 : Colors.black54,
                      height: 1.5,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                if (assignment.fileUrl != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color:
                          (isDark
                              ? Colors.white10
                              : Colors.black.withOpacity(0.05)),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark ? Colors.white24 : Colors.black12,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: FileUtils.getFileTypeColor(
                              assignment.fileUrl!,
                              isDark: isDark,
                            ).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            FileUtils.getFileIcon(assignment.fileUrl!),
                            color: FileUtils.getFileTypeColor(
                              assignment.fileUrl!,
                              isDark: isDark,
                            ),
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Assignment Document',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                              ),
                              Text(
                                FileUtils.getFileType(assignment.fileUrl!),
                                style: TextStyle(
                                  fontSize: 12,
                                  color:
                                      isDark ? Colors.white60 : Colors.black45,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (widget.downloadedFiles.containsKey(assignment.id))
                          TextButton.icon(
                            icon: const Icon(Icons.open_in_new, size: 16),
                            label: const Text('Open'),
                            onPressed: () => widget.onOpen(assignment),
                            style: TextButton.styleFrom(
                              foregroundColor:
                                  isDark
                                      ? AppTheme.darkPrimaryStart
                                      : AppTheme.lightPrimaryStart,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 4,
                              ),
                            ),
                          )
                        else if (widget.downloadProgress.containsKey(
                          assignment.id,
                        ))
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    isDark
                                        ? AppTheme.darkPrimaryStart
                                        : AppTheme.lightPrimaryStart,
                                  ),
                                  value: widget.downloadProgress[assignment.id],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${(widget.downloadProgress[assignment.id]! * 100).toStringAsFixed(0)}%',
                                style: TextStyle(
                                  fontSize: 12,
                                  color:
                                      isDark
                                          ? AppTheme.darkPrimaryStart
                                          : AppTheme.lightPrimaryStart,
                                ),
                              ),
                            ],
                          )
                        else
                          TextButton.icon(
                            icon: const Icon(Icons.download, size: 16),
                            label: const Text('Download'),
                            onPressed: () => widget.onDownload(assignment),
                            style: TextButton.styleFrom(
                              foregroundColor:
                                  isDark
                                      ? AppTheme.darkPrimaryStart
                                      : AppTheme.lightPrimaryStart,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 4,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Row(
                  children: [
                    if (assignment.fileUrl != null) ...[
                      Icon(
                        FileUtils.getFileIcon(assignment.fileUrl!),
                        size: 16,
                        color: isDark ? Colors.white60 : Colors.black45,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Has attachment',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white60 : Colors.black45,
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Expanded(
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 12,
                            backgroundColor: (isDark
                                    ? AppTheme.darkPrimaryStart
                                    : AppTheme.lightPrimaryStart)
                                .withOpacity(0.1),
                            child: Text(
                              assignment.assignedByName.isNotEmpty
                                  ? assignment.assignedByName[0].toUpperCase()
                                  : '?',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color:
                                    isDark
                                        ? AppTheme.darkPrimaryStart
                                        : AppTheme.lightPrimaryStart,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              'Posted by ${assignment.assignedByName}',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? Colors.white60 : Colors.black45,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!isLecturer && !hasSubmitted)
                      Tooltip(
                        message:
                            widget.isOffline
                                ? 'You need to be online to submit assignments'
                                : 'Submit your assignment',
                        child: TextButton.icon(
                          icon: Icon(
                            widget.isOffline
                                ? Icons.cloud_off
                                : Icons.upload_file,
                            size: 16,
                          ),
                          label: Text(
                            widget.isOffline
                                ? 'Offline'
                                : (isOverdue ? 'Submit Late' : 'Submit'),
                          ),
                          onPressed:
                              widget.isOffline
                                  ? null
                                  : () => widget.onSubmit(assignment),
                          style: TextButton.styleFrom(
                            foregroundColor:
                                widget.isOffline
                                    ? Colors.grey
                                    : (isOverdue
                                        ? Colors.red
                                        : (isDark
                                            ? AppTheme.darkPrimaryStart
                                            : AppTheme.lightPrimaryStart)),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                          ),
                        ),
                      )
                    else if (isLecturer)
                      TextButton.icon(
                        icon: const Icon(Icons.people, size: 16),
                        label: const Text('View'),
                        onPressed: () => widget.onViewSubmissions(assignment),
                        style: TextButton.styleFrom(
                          foregroundColor:
                              isDark
                                  ? AppTheme.darkPrimaryStart
                                  : AppTheme.lightPrimaryStart,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showAssignmentOptions(AssignmentModel assignment) {
    DialogUtils.showOptionsBottomSheet(
      context: context,
      title: 'Assignment Options',
      options: [
        OptionItem(
          icon: Icons.delete_outline,
          title: 'Delete Assignment',
          subtitle: 'Permanently remove this assignment and all submissions',
          color: Colors.red,
          onTap: () => widget.onDelete(assignment),
        ),
      ],
    );
  }

  Widget _buildEmptyState(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String message,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 72,
              color:
                  isDark
                      ? AppTheme.darkTextSecondary
                      : AppTheme.lightTextSecondary,
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color:
                    isDark
                        ? AppTheme.darkTextSecondary
                        : AppTheme.lightTextSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color:
                    isDark
                        ? AppTheme.darkTextSecondary
                        : AppTheme.lightTextSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
