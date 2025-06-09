import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/resource_model.dart';
import '../utils/app_theme.dart';
import '../utils/file_utils.dart';

class ResourceItem extends StatelessWidget {
  final ResourceModel resource;
  final String className;
  final String courseCode;
  final bool isLecturer;
  final VoidCallback? onDelete;
  final VoidCallback? onRefresh;

  const ResourceItem({
    Key? key,
    required this.resource,
    required this.className,
    required this.courseCode,
    required this.isLecturer,
    this.onDelete,
    this.onRefresh,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: (isDark ? Colors.grey[800] : Colors.grey[200])!,
          width: 1,
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
          onTap: () => _openResource(context),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with file icon and actions
                Row(
                  children: [
                    // File type icon
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
                        FileUtils.getFileIcon(resource.fileUrl),
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
                            resource.title,
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
                      IconButton(
                        icon: Icon(
                          Icons.download,
                          color:
                              isLecturer
                                  ? (isDark
                                      ? AppTheme.darkSecondaryStart
                                      : AppTheme.lightSecondaryStart)
                                  : (isDark
                                      ? AppTheme.darkPrimaryStart
                                      : AppTheme.lightPrimaryStart),
                        ),
                        onPressed: () => _openResource(context),
                        tooltip: 'Download',
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                // Resource details
                Row(
                  children: [
                    // File type badge
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
                      child: Text(
                        FileUtils.getFileType(resource.fileUrl),
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
                    ),
                    const Spacer(),
                    // Upload info
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'by ${resource.uploadedByName}',
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
                          FileUtils.formatDate(resource.createdAt),
                          style: Theme.of(
                            context,
                          ).textTheme.bodySmall?.copyWith(
                            color:
                                isDark
                                    ? AppTheme.darkTextSecondary
                                    : AppTheme.lightTextSecondary,
                            fontSize: 11,
                          ),
                        ),
                      ],
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

  void _handleAction(BuildContext context, String action) {
    switch (action) {
      case 'download':
        _openResource(context);
        break;
      case 'delete':
        _showDeleteConfirmation(context);
        break;
    }
  }

  void _openResource(BuildContext context) async {
    try {
      final uri = Uri.parse(resource.fileUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Cannot open resource: ${resource.title}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error opening resource: $e'),
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
            title: const Text('Delete Resource'),
            content: Text(
              'Are you sure you want to delete "${resource.title}"?',
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
