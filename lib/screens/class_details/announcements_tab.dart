import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/announcement_model.dart';
import '../../models/class_model.dart';
import '../../providers/auth_provider.dart';
import '../../utils/app_theme.dart';
import '../../utils/dialog_utils.dart';

class AnnouncementsTab extends StatefulWidget {
  final ClassModel classModel;
  final List<AnnouncementModel> announcements;
  final bool isLoading;
  final Function() onRefresh;
  final Function(AnnouncementModel) onDelete;
  final Function() onCreateAnnouncement;
  final String? error;

  const AnnouncementsTab({
    Key? key,
    required this.classModel,
    required this.announcements,
    required this.isLoading,
    required this.onRefresh,
    required this.onDelete,
    required this.onCreateAnnouncement,
    this.error,
  }) : super(key: key);

  @override
  State<AnnouncementsTab> createState() => _AnnouncementsTabState();
}

class _AnnouncementsTabState extends State<AnnouncementsTab> {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isLecturer = Provider.of<AuthProvider>(context).isLecturer;
    final isOffline =
        widget.announcements.isEmpty &&
        widget.error != null &&
        (widget.error?.contains('SocketException') == true ||
            widget.error?.contains('ClientException') == true ||
            widget.error?.contains('Failed host lookup') == true);

    return RefreshIndicator(
      onRefresh: () async => widget.onRefresh(),
      displacement: 40.0,
      color: isDark ? AppTheme.darkPrimaryStart : AppTheme.lightPrimaryStart,
      backgroundColor: isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
      strokeWidth: 3.0,
      child:
          widget.isLoading && widget.announcements.isEmpty
              ? Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(
                    isDark
                        ? AppTheme.darkPrimaryStart
                        : AppTheme.lightPrimaryStart,
                  ),
                ),
              )
              : widget.announcements.isEmpty
              ? isOffline
                  ? _buildOfflineState(context)
                  : _buildEmptyState(
                    context,
                    icon: Icons.announcement,
                    title: 'No announcements yet',
                    message:
                        isLecturer
                            ? 'Tap + to post an announcement for your class'
                            : 'Stay tuned for updates from your lecturer',
                  )
              : ListView.builder(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                itemCount: widget.announcements.length,
                physics: const AlwaysScrollableScrollPhysics(),
                itemBuilder: (context, index) {
                  final announcement = widget.announcements[index];
                  return _buildAnnouncementItem(
                    context,
                    announcement,
                    isLecturer,
                  );
                },
              ),
    );
  }

  Widget _buildAnnouncementItem(
    BuildContext context,
    AnnouncementModel announcement,
    bool isLecturer,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showAnnouncementDetails(announcement),
          onLongPress:
              isLecturer ? () => _showAnnouncementOptions(announcement) : null,
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
                    Text(
                      DateFormat('MMM d').format(announcement.createdAt),
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color:
                            isDark
                                ? AppTheme.darkSecondaryStart
                                : AppTheme.lightSecondaryStart,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      DateFormat('h:mm a').format(announcement.createdAt),
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
                const SizedBox(height: 12),
                ShaderMask(
                  shaderCallback:
                      (bounds) => LinearGradient(
                        colors: [Colors.white, Colors.white.withOpacity(0.8)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ).createShader(bounds),
                  child: Text(
                    announcement.title,
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  announcement.message,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color:
                        isDark
                            ? AppTheme.darkTextSecondary
                            : AppTheme.lightTextSecondary,
                    height: 1.5,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showAnnouncementDetails(AnnouncementModel announcement) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    DialogUtils.showDetailsBottomSheet(
      context: context,
      title: announcement.title,
      subtitle: _getFormattedDate(announcement.createdAt),
      icon: Icons.announcement_outlined,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: (isDark ? AppTheme.darkSurface : Colors.white),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
              ),
            ),
            child: Text(
              announcement.message,
              style: GoogleFonts.inter(
                fontSize: 16,
                height: 1.6,
                color:
                    isDark
                        ? AppTheme.darkTextPrimary
                        : AppTheme.lightTextPrimary,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: (isDark
                        ? AppTheme.darkPrimaryStart
                        : AppTheme.lightPrimaryStart)
                    .withOpacity(0.2),
                child: Text(
                  announcement.postedByName.substring(0, 1).toUpperCase(),
                  style: GoogleFonts.inter(
                    color:
                        isDark
                            ? AppTheme.darkPrimaryStart
                            : AppTheme.lightPrimaryStart,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Posted by',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: isDark ? Colors.white60 : Colors.black45,
                    ),
                  ),
                  Text(
                    announcement.postedByName,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showAnnouncementOptions(AnnouncementModel announcement) {
    DialogUtils.showOptionsBottomSheet(
      context: context,
      title: 'Announcement Options',
      options: [
        OptionItem(
          icon: Icons.delete_outline,
          title: 'Delete Announcement',
          subtitle: 'Permanently remove this announcement',
          color: Colors.red,
          onTap: () => widget.onDelete(announcement),
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

  Widget _buildOfflineState(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.wifi_off_rounded, size: 72, color: Colors.orange),
            const SizedBox(height: 16),
            Text(
              "You're Offline",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.orange,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Connect to the internet to view announcements",
              textAlign: TextAlign.center,
              style: TextStyle(
                color:
                    isDark
                        ? AppTheme.darkTextSecondary
                        : AppTheme.lightTextSecondary,
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              icon: const Icon(Icons.refresh),
              label: const Text("Try Again"),
              onPressed: widget.onRefresh,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.orange,
                side: const BorderSide(color: Colors.orange),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper method for formatting date based on how long ago it was posted
  String _getFormattedDate(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 7) {
      return DateFormat('MMM d, yyyy').format(dateTime);
    } else if (difference.inDays > 0) {
      return '${difference.inDays} ${difference.inDays == 1 ? 'day' : 'days'} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} ${difference.inHours == 1 ? 'hour' : 'hours'} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} ${difference.inMinutes == 1 ? 'minute' : 'minutes'} ago';
    } else {
      return 'Just now';
    }
  }
}

// Static methods to handle announcements data
class AnnouncementsManager {
  // Save announcements to SharedPreferences
  static Future<void> cacheAnnouncements(
    List<AnnouncementModel> announcements,
    String classId,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = announcements.map((a) => a.toJson()).toList();
      await prefs.setString('announcements_$classId', json.encode(data));
    } catch (e) {
      print('Error caching announcements: $e');
    }
  }

  // Load cached announcements from SharedPreferences
  static Future<List<AnnouncementModel>> loadCachedAnnouncements(
    String classId,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedData = prefs.getString('announcements_$classId');

      if (cachedData != null) {
        final cachedList =
            (json.decode(cachedData) as List)
                .map((item) => AnnouncementModel.fromJson(item))
                .toList();

        return cachedList;
      }
    } catch (e) {
      print('Error loading cached announcements: $e');
    }
    return [];
  }
}
