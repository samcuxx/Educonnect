import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/resource_model.dart';
import '../../models/class_model.dart';
import '../../providers/auth_provider.dart';
import '../../utils/app_theme.dart';
import '../../utils/dialog_utils.dart';
import '../../utils/download_manager.dart';
import '../../utils/file_utils.dart';

class ResourcesTab extends StatefulWidget {
  final ClassModel classModel;
  final List<ResourceModel> resources;
  final bool isLoading;
  final Map<String, double> downloadProgress;
  final Map<String, String> downloadedFiles;
  final Function() onRefresh;
  final Function(ResourceModel) onDelete;
  final Function(ResourceModel) onDownload;
  final Function(ResourceModel) onOpen;
  final Function() onUploadResource;
  final bool isOffline;

  const ResourcesTab({
    Key? key,
    required this.classModel,
    required this.resources,
    required this.isLoading,
    required this.downloadProgress,
    required this.downloadedFiles,
    required this.onRefresh,
    required this.onDelete,
    required this.onDownload,
    required this.onOpen,
    required this.onUploadResource,
    this.isOffline = false,
  }) : super(key: key);

  @override
  State<ResourcesTab> createState() => _ResourcesTabState();
}

class _ResourcesTabState extends State<ResourcesTab> {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isLecturer = Provider.of<AuthProvider>(context).isLecturer;

    return RefreshIndicator(
      onRefresh: () async => widget.onRefresh(),
      displacement: 40.0,
      color: isDark ? AppTheme.darkPrimaryStart : AppTheme.lightPrimaryStart,
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
                widget.isLoading && widget.resources.isEmpty
                    ? Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(
                          isDark
                              ? AppTheme.darkPrimaryStart
                              : AppTheme.lightPrimaryStart,
                        ),
                      ),
                    )
                    : widget.resources.isEmpty
                    ? _buildEmptyState(
                      context,
                      icon: Icons.folder_open,
                      title: 'No resources shared yet',
                      message:
                          isLecturer
                              ? 'Tap + to upload files for your students'
                              : 'Resources will be shared by your lecturer soon',
                    )
                    : ListView.builder(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      itemCount: widget.resources.length,
                      itemBuilder: (context, index) {
                        final resource = widget.resources[index];
                        return _buildResourceItem(
                          context,
                          resource,
                          isLecturer,
                        );
                      },
                    ),
          ),
        ],
      ),
    );
  }

  Widget _buildResourceItem(
    BuildContext context,
    ResourceModel resource,
    bool isLecturer,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bool isDownloading = widget.downloadProgress.containsKey(resource.id);
    final bool isDownloaded = widget.downloadedFiles.containsKey(resource.id);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isDownloaded ? () => widget.onOpen(resource) : null,
          onLongPress: isLecturer ? () => _showResourceOptions(resource) : null,
          borderRadius: BorderRadius.circular(28),
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? AppTheme.darkSurface : Colors.white,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
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
                        color: FileUtils.getFileTypeColor(
                          resource.fileUrl,
                          isDark: isDark,
                        ).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        FileUtils.getFileIcon(resource.fileUrl),
                        color: FileUtils.getFileTypeColor(
                          resource.fileUrl,
                          isDark: isDark,
                        ),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            resource.title,
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
                            DateFormat(
                              'MMM d, yyyy',
                            ).format(resource.createdAt),
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color:
                                  isDark
                                      ? AppTheme.darkTextSecondary
                                      : AppTheme.lightTextSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (isDownloaded)
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
                              'Downloaded',
                              style: TextStyle(
                                color: Colors.green,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      )
                    else if (isDownloading)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: (isDark
                                  ? AppTheme.darkSecondaryStart
                                  : AppTheme.lightSecondaryStart)
                              .withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  isDark
                                      ? AppTheme.darkSecondaryStart
                                      : AppTheme.lightSecondaryStart,
                                ),
                                value: widget.downloadProgress[resource.id],
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '${(widget.downloadProgress[resource.id]! * 100).toStringAsFixed(0)}%',
                              style: TextStyle(
                                fontSize: 12,
                                color:
                                    isDark
                                        ? AppTheme.darkSecondaryStart
                                        : AppTheme.lightSecondaryStart,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    if (resource.fileUrl.isNotEmpty) ...[
                      Icon(
                        FileUtils.getFileIcon(resource.fileUrl),
                        size: 16,
                        color:
                            isDark
                                ? AppTheme.darkTextSecondary
                                : AppTheme.lightTextSecondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        FileUtils.getFileType(resource.fileUrl),
                        style: TextStyle(
                          fontSize: 12,
                          color:
                              isDark
                                  ? AppTheme.darkTextSecondary
                                  : AppTheme.lightTextSecondary,
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
                                    ? AppTheme.darkSecondaryStart
                                    : AppTheme.lightSecondaryStart)
                                .withOpacity(0.1),
                            child: Text(
                              resource.uploadedByName.isNotEmpty
                                  ? resource.uploadedByName[0].toUpperCase()
                                  : '?',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color:
                                    isDark
                                        ? AppTheme.darkSecondaryStart
                                        : AppTheme.lightSecondaryStart,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              'Uploaded by ${resource.uploadedByName}',
                              style: TextStyle(
                                fontSize: 12,
                                color:
                                    isDark
                                        ? AppTheme.darkTextSecondary
                                        : AppTheme.lightTextSecondary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!isDownloaded && !isDownloading)
                      TextButton.icon(
                        icon: const Icon(Icons.download, size: 16),
                        label: const Text('Download'),
                        onPressed: () => widget.onDownload(resource),
                        style: TextButton.styleFrom(
                          foregroundColor:
                              isDark
                                  ? AppTheme.darkSecondaryStart
                                  : AppTheme.lightSecondaryStart,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                        ),
                      )
                    else if (isDownloaded)
                      TextButton.icon(
                        icon: const Icon(Icons.open_in_new, size: 16),
                        label: const Text('Open'),
                        onPressed: () => widget.onOpen(resource),
                        style: TextButton.styleFrom(
                          foregroundColor:
                              isDark
                                  ? AppTheme.darkSecondaryStart
                                  : AppTheme.lightSecondaryStart,
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

  void _showResourceOptions(ResourceModel resource) {
    DialogUtils.showOptionsBottomSheet(
      context: context,
      title: 'Resource Options',
      options: [
        OptionItem(
          icon: Icons.delete_outline,
          title: 'Delete Resource',
          subtitle: 'Permanently remove this resource',
          color: Colors.red,
          onTap: () => widget.onDelete(resource),
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
