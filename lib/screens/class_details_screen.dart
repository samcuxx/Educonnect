import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_selector/file_selector.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as path;
import 'package:connectivity_plus/connectivity_plus.dart';
import '../models/class_model.dart';
import '../models/user_model.dart';
import '../models/announcement_model.dart';
import '../models/resource_model.dart';
import '../models/assignment_model.dart';
import '../models/submission_model.dart';
import '../providers/auth_provider.dart';
import '../providers/class_provider.dart';
import '../services/supabase_service.dart';
import '../services/connectivity_service.dart';
import '../utils/app_theme.dart';
import '../utils/global_download_manager.dart';
import 'submissions_screen.dart';

class ClassDetailsScreen extends StatefulWidget {
  final ClassModel classModel;

  const ClassDetailsScreen({Key? key, required this.classModel})
    : super(key: key);

  @override
  State<ClassDetailsScreen> createState() => _ClassDetailsScreenState();
}

class _ClassDetailsScreenState extends State<ClassDetailsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoadingCount = false;
  bool _isLoadingAnnouncements = false;
  bool _isLoadingResources = false;
  bool _isLoadingAssignments = false;
  int _studentsCount = 0;
  List<AnnouncementModel> _announcements = [];
  List<ResourceModel> _resources = [];
  List<AssignmentModel> _assignments = [];
  Map<String, bool> _assignmentSubmissions =
      {}; // Track if student has submitted
  DateTime? _lastAnnouncementCheck;
  bool _initialLoadDone = false;

  // Add new properties for resource downloads
  Map<String, double> _downloadProgress = {};
  Map<String, String> _downloadedFiles = {};

  // Add new properties for assignment downloads
  Map<String, double> _assignmentDownloadProgress = {};
  Map<String, String> _downloadedAssignments = {};

  // Add submission download tracking
  Map<String, double> _submissionDownloadProgress = {};
  Map<String, String> _downloadedSubmissions = {};

  bool _isOffline = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    // Only fetch student count if the user is a lecturer
    if (authProvider.isLecturer) {
      _loadStudentsCount();
    }

    // Set up tab controller listener
    _tabController.addListener(_handleTabChange);

    // Initial load of resources and check for announcements
    _checkAnnouncementUpdates();
    _loadCachedAnnouncements();
    _loadResources();
    _loadAssignments();

    // Load downloaded files info using global download manager
    _loadDownloadedFiles();
    _loadDownloadedAssignments();
    _loadDownloadedSubmissions();
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    super.dispose();
  }

  // Handle tab changes
  void _handleTabChange() {
    if (_tabController.index == 0 && !_isLoadingAnnouncements) {
      // If switching to announcements tab, check for updates
      _checkAnnouncementUpdates();
    } else if (_tabController.index == 1) {
      // If switching to resources tab
      _loadResources();
    } else if (_tabController.index == 2) {
      // If switching to assignments tab
      _loadAssignments();
    }
  }

  // Load assignments for the class
  Future<void> _loadAssignments() async {
    if (!mounted) return;

    setState(() {
      _isLoadingAssignments = true;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final supabaseService = authProvider.supabaseService;

      // Load from cache first (this will show cached data immediately)
      final assignments = await supabaseService.getClassAssignments(
        widget.classModel.id,
        loadFromCache: true,
      );

      if (mounted) {
        setState(() {
          _assignments = assignments;
          _isLoadingAssignments = false;
          _isOffline = false;
        });
      }

      // Load submission status for students
      if (!authProvider.isLecturer && assignments.isNotEmpty) {
        await _loadSubmissionStatus(assignments);
      }

      // Then try to refresh from network without showing loading indicator
      try {
        // Try to get fresh data if we're online
        final freshAssignments = await supabaseService.getClassAssignments(
          widget.classModel.id,
          loadFromCache: false,
        );

        if (mounted) {
          setState(() {
            _assignments = freshAssignments;
            _isOffline = false;
          });
        }

        // Reload submission status with fresh assignments
        if (!authProvider.isLecturer && freshAssignments.isNotEmpty) {
          await _loadSubmissionStatus(freshAssignments);
        }
      } catch (e) {
        // Silently fail when refreshing - we already have cached data
        print('Silent error refreshing assignments: $e');
        // Update offline status
        _updateOfflineStatus(true);
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoadingAssignments = false;
      });

      // Only show error if we couldn't load from cache
      if (_assignments.isEmpty) {
        String errorMessage = 'Failed to load assignments';
        bool isOffline = false;

        if (e.toString().contains('SocketException') ||
            e.toString().contains('ClientException') ||
            e.toString().contains('Failed host lookup')) {
          errorMessage = 'You\'re offline. Showing cached data.';
          isOffline = true;
        }

        _updateOfflineStatus(isOffline);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  // Check if we need to update announcements (based on time since last check)
  Future<void> _checkAnnouncementUpdates() async {
    // Only check for updates if we haven't checked recently (last 5 minutes)
    final now = DateTime.now();
    if (_lastAnnouncementCheck != null &&
        now.difference(_lastAnnouncementCheck!).inMinutes < 5 &&
        _initialLoadDone) {
      return; // Skip if we checked less than 5 minutes ago
    }

    // Check connectivity first - only refresh from network if online
    bool isOnline = true;
    try {
      final connectivityService = Provider.of<ConnectivityService>(
        context,
        listen: false,
      );
      isOnline = await connectivityService.checkConnectivity();
    } catch (e) {
      isOnline = false;
      print('Error checking connectivity: $e');
    }

    // Always try to load announcements (will use cache if offline)
    await _loadAnnouncements();
    _lastAnnouncementCheck = now;
    _initialLoadDone = true;

    // Update offline status
    _updateOfflineStatus(!isOnline);
  }

  // Load cached announcements from SharedPreferences while we check for updates
  Future<void> _loadCachedAnnouncements() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedData = prefs.getString(
        'announcements_${widget.classModel.id}',
      );

      if (cachedData != null) {
        final cachedList =
            (json.decode(cachedData) as List).map((item) {
              return AnnouncementModel.fromJson(item);
            }).toList();

        setState(() {
          _announcements = cachedList;
        });
        print('Loaded ${cachedList.length} announcements from cache');
      }
    } catch (e) {
      print('Error loading cached announcements: $e');
    }
  }

  // Save announcements to SharedPreferences
  Future<void> _cacheAnnouncements(
    List<AnnouncementModel> announcements,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = announcements.map((a) => a.toJson()).toList();
      await prefs.setString(
        'announcements_${widget.classModel.id}',
        json.encode(data),
      );
    } catch (e) {
      print('Error caching announcements: $e');
    }
  }

  Future<void> _loadStudentsCount() async {
    if (!mounted) return;

    setState(() {
      _isLoadingCount = true;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final supabaseService = authProvider.supabaseService;

      // Try to get student count
      final count = await supabaseService.getClassStudentsCount(
        widget.classModel.id,
      );

      if (mounted) {
        setState(() {
          _studentsCount = count;
          _isLoadingCount = false;
          _isOffline = false;
        });
      }
    } catch (e) {
      // Handle error
      if (!mounted) return;

      setState(() {
        _isLoadingCount = false;
      });

      String errorMessage = 'Failed to load students count';
      bool isOffline = false;

      // Check if the error is network-related
      if (e.toString().contains('SocketException') ||
          e.toString().contains('ClientException') ||
          e.toString().contains('Failed host lookup')) {
        errorMessage = 'You\'re offline. Using cached data.';
        isOffline = true;
      }

      _updateOfflineStatus(isOffline);

      // Only show error if we have no data
      if (_studentsCount == 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: isOffline ? Colors.orange : Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _loadAnnouncements() async {
    if (_isLoadingAnnouncements) return;

    setState(() {
      _isLoadingAnnouncements = true;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final supabaseService = authProvider.supabaseService;

      final announcements = await supabaseService.getClassAnnouncements(
        widget.classModel.id,
      );

      // Cache the fetched announcements
      _cacheAnnouncements(announcements);

      if (mounted) {
        setState(() {
          _announcements = announcements;
          _isLoadingAnnouncements = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingAnnouncements = false;
        });

        // Only show error if we don't have cached data
        if (_announcements.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to load announcements: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  // Load resources
  Future<void> _loadResources() async {
    if (!mounted) return;

    setState(() {
      _isLoadingResources = true;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final supabaseService = authProvider.supabaseService;

      // Load from cache first (this will show cached data immediately)
      final resources = await supabaseService.getClassResources(
        widget.classModel.id,
        loadFromCache: true,
      );

      if (mounted) {
        setState(() {
          _resources = resources;
          _isLoadingResources = false;
          _isOffline = false;
        });
      }

      // Then try to refresh from network without showing loading indicator
      try {
        // Try to get fresh data if we're online
        final freshResources = await supabaseService.getClassResources(
          widget.classModel.id,
          loadFromCache: false,
        );

        if (mounted) {
          setState(() {
            _resources = freshResources;
            _isOffline = false;
          });
        }
      } catch (e) {
        // Silently fail when refreshing - we already have cached data
        print('Silent error refreshing resources: $e');
        // Update offline status
        _updateOfflineStatus(true);
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoadingResources = false;
      });

      // Only show error if we couldn't load from cache
      if (_resources.isEmpty && mounted) {
        String errorMessage = 'Unable to load resources';
        bool isOffline = false;

        if (e.toString().contains('SocketException') ||
            e.toString().contains('ClientException') ||
            e.toString().contains('Failed host lookup')) {
          errorMessage = 'You\'re offline. Showing cached data.';
          isOffline = true;
        }

        _updateOfflineStatus(isOffline);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  // Show confirmation dialog before leaving or deleting a class
  Future<bool> _showConfirmationDialog(String title, String message) async {
    final result = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(title),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Confirm'),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
              ),
            ],
          ),
    );

    return result ?? false;
  }

  // Handle leaving a class (for students)
  Future<void> _leaveClass() async {
    final confirmed = await _showConfirmationDialog(
      'Leave Class',
      'Are you sure you want to leave this class? You will need the class code to rejoin.',
    );

    if (!confirmed) return;

    try {
      final classProvider = Provider.of<ClassProvider>(context, listen: false);
      await classProvider.leaveClass(widget.classModel.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You have left the class'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to leave class: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Handle deleting a class (for lecturers)
  Future<void> _deleteClass() async {
    final confirmed = await _showConfirmationDialog(
      'Delete Class',
      'Are you sure you want to delete this class? This action cannot be undone and will remove all students from the class.',
    );

    if (!confirmed) return;

    try {
      final classProvider = Provider.of<ClassProvider>(context, listen: false);
      await classProvider.deleteClass(widget.classModel.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Class deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete class: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Create a new announcement
  Future<void> _createAnnouncement() async {
    final formKey = GlobalKey<FormState>();
    final titleController = TextEditingController();
    final messageController = TextEditingController();
    bool sendSms = true; // Default to true

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setModalState) => Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color:
                        Theme.of(context).brightness == Brightness.dark
                            ? AppTheme.darkSurface
                            : Colors.white,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(28),
                    ),
                    border: Border.all(
                      color:
                          Theme.of(context).brightness == Brightness.dark
                              ? AppTheme.darkBorder
                              : AppTheme.lightBorder,
                    ),
                  ),
                  padding: EdgeInsets.only(
                    bottom: MediaQuery.of(context).viewInsets.bottom,
                    left: 16,
                    right: 16,
                    top: 16,
                  ),
                  child: SingleChildScrollView(
                    child: Form(
                      key: formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          ShaderMask(
                            shaderCallback:
                                (bounds) => LinearGradient(
                                  colors:
                                      Theme.of(context).brightness ==
                                              Brightness.dark
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
                              'Upload Resource',
                              style: GoogleFonts.inter(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          TextFormField(
                            controller: titleController,
                            decoration: InputDecoration(
                              labelText: 'Title',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(28),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(28),
                                borderSide: BorderSide(
                                  color:
                                      Theme.of(context).brightness ==
                                              Brightness.dark
                                          ? AppTheme.darkBorder
                                          : AppTheme.lightBorder,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(28),
                                borderSide: BorderSide(
                                  color:
                                      Theme.of(context).brightness ==
                                              Brightness.dark
                                          ? AppTheme.darkSecondaryStart
                                          : AppTheme.lightSecondaryStart,
                                  width: 2,
                                ),
                              ),
                            ),
                            style: GoogleFonts.inter(),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter a title';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: messageController,
                            decoration: InputDecoration(
                              labelText: 'Message',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(28),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(28),
                                borderSide: BorderSide(
                                  color:
                                      Theme.of(context).brightness ==
                                              Brightness.dark
                                          ? AppTheme.darkBorder
                                          : AppTheme.lightBorder,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(28),
                                borderSide: BorderSide(
                                  color:
                                      Theme.of(context).brightness ==
                                              Brightness.dark
                                          ? AppTheme.darkSecondaryStart
                                          : AppTheme.lightSecondaryStart,
                                  width: 2,
                                ),
                              ),
                              alignLabelWithHint: true,
                            ),
                            style: GoogleFonts.inter(),
                            maxLines: 5,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter a message';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 20),
                          // SMS notification toggle
                          Row(
                            children: [
                              Theme(
                                data: Theme.of(context).copyWith(
                                  checkboxTheme: CheckboxThemeData(
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  ),
                                ),
                                child: Checkbox(
                                  value: sendSms,
                                  activeColor:
                                      Theme.of(context).brightness ==
                                              Brightness.dark
                                          ? AppTheme.darkSecondaryStart
                                          : AppTheme.lightSecondaryStart,
                                  onChanged: (value) {
                                    setModalState(() {
                                      sendSms = value ?? true;
                                    });
                                  },
                                ),
                              ),
                              Text(
                                'Send SMS notification to students',
                                style: GoogleFonts.inter(),
                              ),
                              const SizedBox(width: 8),
                              Tooltip(
                                message:
                                    'Students must have added their phone numbers to receive SMS notifications',
                                child: Icon(
                                  Icons.info_outline,
                                  size: 16,
                                  color:
                                      Theme.of(context).brightness ==
                                              Brightness.dark
                                          ? AppTheme.darkTextSecondary
                                          : AppTheme.lightTextSecondary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors:
                                    Theme.of(context).brightness ==
                                            Brightness.dark
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
                              ),
                              borderRadius: BorderRadius.circular(28),
                              border: Border.all(
                                color:
                                    Theme.of(context).brightness ==
                                            Brightness.dark
                                        ? AppTheme.darkBorder
                                        : AppTheme.lightBorder,
                                width: 1,
                              ),
                            ),
                            child: ElevatedButton(
                              onPressed: () async {
                                if (formKey.currentState!.validate()) {
                                  Navigator.pop(context, {
                                    'title': titleController.text.trim(),
                                    'message': messageController.text.trim(),
                                    'sendSms': sendSms,
                                  });
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                foregroundColor: Colors.white,
                                backgroundColor: Colors.transparent,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(28),
                                ),
                              ),
                              child: Text(
                                'Post Announcement',
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ),
                ),
          ),
    ).then((data) async {
      if (data != null && data is Map<String, dynamic>) {
        try {
          setState(() {
            _isLoadingAnnouncements = true;
          });

          final authProvider = Provider.of<AuthProvider>(
            context,
            listen: false,
          );
          final supabaseService = authProvider.supabaseService;

          // Show sending indicator
          if (data['sendSms'] == true) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Posting announcement and sending SMS notifications...',
                ),
                duration: Duration(seconds: 2),
              ),
            );
          }

          final announcement = await supabaseService.createAnnouncement(
            classId: widget.classModel.id,
            title: data['title']!,
            message: data['message']!,
            sendSms: data['sendSms'] ?? false,
          );

          setState(() {
            _announcements.insert(0, announcement);
            _isLoadingAnnouncements = false;
          });

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  data['sendSms'] == true
                      ? 'Announcement posted and SMS notifications sent'
                      : 'Announcement posted successfully',
                ),
                backgroundColor: Colors.green,
              ),
            );
          }
        } catch (e) {
          setState(() {
            _isLoadingAnnouncements = false;
          });

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Failed to post announcement: ${e.toString()}'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      }
    });
  }

  // Delete an announcement
  Future<void> _deleteAnnouncement(AnnouncementModel announcement) async {
    final confirmed = await _showConfirmationDialog(
      'Delete Announcement',
      'Are you sure you want to delete this announcement? This action cannot be undone.',
    );

    if (!confirmed) return;

    try {
      setState(() {
        _isLoadingAnnouncements = true;
      });

      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final supabaseService = authProvider.supabaseService;

      await supabaseService.deleteAnnouncement(
        announcement.id,
        widget.classModel.id,
      );

      setState(() {
        _announcements.removeWhere((a) => a.id == announcement.id);
        _isLoadingAnnouncements = false;
      });

      // Update cache after deletion
      _cacheAnnouncements(_announcements);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Announcement deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isLoadingAnnouncements = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete announcement: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Show announcement options for lecturers
  void _showAnnouncementOptions(AnnouncementModel announcement) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder:
          (context) => Container(
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.darkSurface : Colors.white,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  decoration: BoxDecoration(
                    color:
                        isDark
                            ? AppTheme.darkSecondaryStart
                            : AppTheme.lightSecondaryStart,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(28),
                    ),
                  ),
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.settings,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Announcement Options',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close, color: Colors.white),
                      ),
                    ],
                  ),
                ),

                // Options
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.delete_outline,
                            color: Colors.red,
                            size: 20,
                          ),
                        ),
                        title: const Text(
                          'Delete Announcement',
                          style: TextStyle(fontWeight: FontWeight.w500),
                        ),
                        subtitle: const Text(
                          'Permanently remove this announcement',
                          style: TextStyle(fontSize: 12),
                        ),
                        onTap: () {
                          Navigator.pop(context);
                          _deleteAnnouncement(announcement);
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
    );
  }

  // Delete a resource
  Future<void> _deleteResource(ResourceModel resource) async {
    final confirmed = await _showConfirmationDialog(
      'Delete Resource',
      'Are you sure you want to delete this resource? This action cannot be undone.',
    );

    if (!confirmed) return;

    try {
      setState(() {
        _isLoadingResources = true;
      });

      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final supabaseService = authProvider.supabaseService;

      await supabaseService.deleteResource(resource.id, widget.classModel.id);

      setState(() {
        _resources.removeWhere((r) => r.id == resource.id);
        _isLoadingResources = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Resource deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isLoadingResources = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete resource: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Show resource options for lecturers
  void _showResourceOptions(ResourceModel resource) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder:
          (context) => Container(
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.darkSurface : Colors.white,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  decoration: BoxDecoration(
                    color:
                        isDark
                            ? AppTheme.darkSecondaryStart
                            : AppTheme.lightSecondaryStart,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(28),
                    ),
                  ),
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.settings,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Resource Options',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close, color: Colors.white),
                      ),
                    ],
                  ),
                ),

                // Options
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.delete_outline,
                            color: Colors.red,
                            size: 20,
                          ),
                        ),
                        title: const Text(
                          'Delete Resource',
                          style: TextStyle(fontWeight: FontWeight.w500),
                        ),
                        subtitle: const Text(
                          'Permanently remove this resource',
                          style: TextStyle(fontSize: 12),
                        ),
                        onTap: () {
                          Navigator.pop(context);
                          _deleteResource(resource);
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
    );
  }

  // Delete an assignment
  Future<void> _deleteAssignment(AssignmentModel assignment) async {
    final confirmed = await _showConfirmationDialog(
      'Delete Assignment',
      'Are you sure you want to delete this assignment? This action cannot be undone and will remove all related submissions.',
    );

    if (!confirmed) return;

    try {
      setState(() {
        _isLoadingAssignments = true;
      });

      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final supabaseService = authProvider.supabaseService;

      await supabaseService.deleteAssignment(
        assignment.id,
        widget.classModel.id,
      );

      setState(() {
        _assignments.removeWhere((a) => a.id == assignment.id);
        _isLoadingAssignments = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Assignment deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isLoadingAssignments = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete assignment: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Show assignment options for lecturers
  void _showAssignmentOptions(AssignmentModel assignment) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder:
          (context) => Container(
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.darkSurface : Colors.white,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  decoration: BoxDecoration(
                    color:
                        isDark
                            ? AppTheme.darkSecondaryStart
                            : AppTheme.lightSecondaryStart,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(28),
                    ),
                  ),
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.settings,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Assignment Options',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close, color: Colors.white),
                      ),
                    ],
                  ),
                ),

                // Options
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.delete_outline,
                            color: Colors.red,
                            size: 20,
                          ),
                        ),
                        title: const Text(
                          'Delete Assignment',
                          style: TextStyle(fontWeight: FontWeight.w500),
                        ),
                        subtitle: const Text(
                          'Permanently remove this assignment and all submissions',
                          style: TextStyle(fontSize: 12),
                        ),
                        onTap: () {
                          Navigator.pop(context);
                          _deleteAssignment(assignment);
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
    );
  }

  // Upload a new resource file
  Future<void> _uploadResource() async {
    final formKey = GlobalKey<FormState>();
    final titleController = TextEditingController();
    File? selectedFile;
    String? fileName;
    bool isUploading = false;
    bool sendSms = true; // Default to true

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setModalState) => Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color:
                        Theme.of(context).brightness == Brightness.dark
                            ? AppTheme.darkSurface
                            : Colors.white,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(28),
                    ),
                    border: Border.all(
                      color:
                          Theme.of(context).brightness == Brightness.dark
                              ? AppTheme.darkBorder
                              : AppTheme.lightBorder,
                    ),
                  ),
                  padding: EdgeInsets.only(
                    bottom: MediaQuery.of(context).viewInsets.bottom,
                    left: 16,
                    right: 16,
                    top: 16,
                  ),
                  child: SingleChildScrollView(
                    child: Form(
                      key: formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          ShaderMask(
                            shaderCallback:
                                (bounds) => LinearGradient(
                                  colors:
                                      Theme.of(context).brightness ==
                                              Brightness.dark
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
                              'Upload Resource',
                              style: GoogleFonts.inter(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: titleController,
                            decoration: const InputDecoration(
                              labelText: 'Title',
                              border: OutlineInputBorder(),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter a title';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          // File picker
                          Container(
                            decoration: BoxDecoration(
                              border: Border.all(
                                color:
                                    Theme.of(context).brightness ==
                                            Brightness.dark
                                        ? AppTheme.darkBorder
                                        : AppTheme.lightBorder,
                              ),
                              borderRadius: BorderRadius.circular(28),
                            ),
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                ElevatedButton.icon(
                                  icon: const Icon(Icons.attach_file_outlined),
                                  label: Text(
                                    'Select File',
                                    style: GoogleFonts.inter(),
                                  ),
                                  onPressed: () async {
                                    try {
                                      // Use file_selector to pick files
                                      final XTypeGroup allFiles = XTypeGroup(
                                        label: 'All Files',
                                        extensions: [
                                          'pdf',
                                          'doc',
                                          'docx',
                                          'ppt',
                                          'pptx',
                                          'txt',
                                          'jpg',
                                          'jpeg',
                                          'png',
                                        ],
                                      );

                                      final XFile? pickedFile = await openFile(
                                        acceptedTypeGroups: [allFiles],
                                      );

                                      if (pickedFile != null) {
                                        final path = pickedFile.path;
                                        print("Selected file path: $path");

                                        // Create the file object
                                        final file = File(path);

                                        // Check if file exists and is readable
                                        if (await file.exists()) {
                                          setModalState(() {
                                            selectedFile = file;
                                            fileName = pickedFile.name;
                                          });
                                        } else {
                                          if (mounted) {
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              const SnackBar(
                                                content: Text(
                                                  'File not found or cannot be accessed',
                                                ),
                                                backgroundColor: Colors.red,
                                              ),
                                            );
                                          }
                                        }
                                      }
                                    } catch (e) {
                                      print("Error picking file: $e");
                                      if (mounted) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              'Error selecting file: $e',
                                            ),
                                            backgroundColor: Colors.red,
                                          ),
                                        );
                                      }
                                    }
                                  },
                                  style: ElevatedButton.styleFrom(
                                    foregroundColor:
                                        Theme.of(context).brightness ==
                                                Brightness.dark
                                            ? AppTheme.darkSecondaryStart
                                            : AppTheme.lightSecondaryStart,
                                    backgroundColor: Colors.transparent,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 16,
                                    ),
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(28),
                                      side: BorderSide(
                                        color:
                                            Theme.of(context).brightness ==
                                                    Brightness.dark
                                                ? AppTheme.darkSecondaryStart
                                                : AppTheme.lightSecondaryStart,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                if (fileName != null) ...[
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color:
                                          Theme.of(context).brightness ==
                                                  Brightness.dark
                                              ? AppTheme.darkSurface
                                                  .withOpacity(0.7)
                                              : Colors.blue.shade50,
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color:
                                            Theme.of(context).brightness ==
                                                    Brightness.dark
                                                ? AppTheme.darkBorder
                                                : Colors.blue.withOpacity(0.3),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.description_outlined,
                                          color:
                                              Theme.of(context).brightness ==
                                                      Brightness.dark
                                                  ? AppTheme.darkSecondaryStart
                                                  : Colors.blue,
                                          size: 22,
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                fileName!,
                                                style: GoogleFonts.inter(
                                                  fontWeight: FontWeight.bold,
                                                  color:
                                                      Theme.of(
                                                                context,
                                                              ).brightness ==
                                                              Brightness.dark
                                                          ? AppTheme
                                                              .darkTextPrimary
                                                          : Colors.black87,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              if (selectedFile != null)
                                                FutureBuilder<int>(
                                                  future:
                                                      selectedFile!.length(),
                                                  builder: (context, snapshot) {
                                                    if (snapshot.hasData) {
                                                      final kb =
                                                          snapshot.data! / 1024;
                                                      return Text(
                                                        '${kb.toStringAsFixed(1)} KB',
                                                        style: GoogleFonts.inter(
                                                          fontSize: 12,
                                                          color:
                                                              Theme.of(
                                                                        context,
                                                                      ).brightness ==
                                                                      Brightness
                                                                          .dark
                                                                  ? AppTheme
                                                                      .darkTextSecondary
                                                                  : Colors
                                                                      .black54,
                                                        ),
                                                      );
                                                    }
                                                    return const SizedBox();
                                                  },
                                                ),
                                            ],
                                          ),
                                        ),
                                        IconButton(
                                          icon: const Icon(
                                            Icons.close,
                                            size: 18,
                                          ),
                                          onPressed: () {
                                            setModalState(() {
                                              selectedFile = null;
                                              fileName = null;
                                            });
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),

                          // SMS notification toggle
                          Row(
                            children: [
                              Checkbox(
                                value: sendSms,
                                onChanged: (value) {
                                  setModalState(() {
                                    sendSms = value ?? true;
                                  });
                                },
                              ),
                              const Text('Send SMS notification to students'),
                              const Tooltip(
                                message:
                                    'Students must have added their phone numbers to receive SMS notifications',
                                child: Icon(Icons.info_outline, size: 16),
                              ),
                            ],
                          ),

                          const SizedBox(height: 24),
                          Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors:
                                    Theme.of(context).brightness ==
                                            Brightness.dark
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
                              ),
                              borderRadius: BorderRadius.circular(28),
                              border: Border.all(
                                color:
                                    Theme.of(context).brightness ==
                                            Brightness.dark
                                        ? AppTheme.darkBorder
                                        : AppTheme.lightBorder,
                                width: 1,
                              ),
                            ),
                            child: ElevatedButton(
                              onPressed:
                                  isUploading
                                      ? null
                                      : () async {
                                        if (formKey.currentState!.validate() &&
                                            selectedFile != null) {
                                          try {
                                            // Check if file still exists before proceeding
                                            if (!await selectedFile!.exists()) {
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                const SnackBar(
                                                  content: Text(
                                                    'File no longer exists or cannot be accessed',
                                                  ),
                                                  backgroundColor: Colors.red,
                                                ),
                                              );
                                              return;
                                            }

                                            setModalState(() {
                                              isUploading = true;
                                            });

                                            Navigator.pop(context, {
                                              'title':
                                                  titleController.text.trim(),
                                              'file': selectedFile,
                                              'sendSms': sendSms,
                                            });
                                          } catch (e) {
                                            print(
                                              "Error checking file before upload: $e",
                                            );
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  'Error preparing file: $e',
                                                ),
                                                backgroundColor: Colors.red,
                                              ),
                                            );
                                            setModalState(() {
                                              isUploading = false;
                                            });
                                          }
                                        } else if (selectedFile == null) {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                'Please select a file',
                                              ),
                                              backgroundColor: Colors.red,
                                            ),
                                          );
                                        }
                                      },
                              style: ElevatedButton.styleFrom(
                                foregroundColor: Colors.white,
                                backgroundColor: Colors.transparent,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(28),
                                ),
                              ),
                              child:
                                  isUploading
                                      ? const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white,
                                            ),
                                          ),
                                          SizedBox(width: 12),
                                          Text('Preparing...'),
                                        ],
                                      )
                                      : Text(
                                        'Upload Resource',
                                        style: GoogleFonts.inter(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ),
                ),
          ),
    ).then((data) async {
      if (data != null && data is Map<String, dynamic>) {
        try {
          setState(() {
            _isLoadingResources = true;
          });

          // Show uploading indicator
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                  SizedBox(width: 16),
                  Text('Uploading resource...'),
                ],
              ),
              duration: Duration(seconds: 30),
            ),
          );

          final authProvider = Provider.of<AuthProvider>(
            context,
            listen: false,
          );
          final supabaseService = authProvider.supabaseService;

          // Show SMS sending indication
          if (data['sendSms'] == true) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Uploading resource and sending SMS notifications...',
                ),
                duration: Duration(seconds: 2),
              ),
            );
          }

          final resource = await supabaseService.uploadResource(
            classId: widget.classModel.id,
            title: data['title'],
            file: data['file'],
            sendSms: data['sendSms'] ?? false,
          );

          setState(() {
            _resources.insert(0, resource);
            _isLoadingResources = false;
          });

          // Clear previous snackbar
          ScaffoldMessenger.of(context).hideCurrentSnackBar();

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  data['sendSms'] == true
                      ? 'Resource uploaded and SMS notifications sent'
                      : 'Resource uploaded successfully',
                ),
                backgroundColor: Colors.green,
              ),
            );
          }
        } catch (e) {
          print("Error during upload process: $e");
          setState(() {
            _isLoadingResources = false;
          });

          // Clear previous snackbar
          ScaffoldMessenger.of(context).hideCurrentSnackBar();

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Failed to upload resource: ${e.toString()}'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      }
    });
  }

  // Load downloaded files info
  Future<void> _loadDownloadedFiles() async {
    try {
      final downloadedFiles = await globalDownloadManager.loadDownloadedFiles();
      setState(() {
        _downloadedFiles = downloadedFiles;
      });
    } catch (e) {
      print('Error loading downloaded files: $e');
    }
  }

  // Save downloaded files info
  Future<void> _saveDownloadedFiles() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // Save to global storage instead of per-class storage
      await prefs.setString(
        'downloaded_resources_all',
        json.encode(_downloadedFiles),
      );
    } catch (e) {
      print('Error saving downloaded files: $e');
    }
  }

  // Add method to download a file
  Future<void> _downloadFile(ResourceModel resource) async {
    if (_downloadProgress.containsKey(resource.id)) {
      return; // Already downloading
    }

    // Check connectivity before attempting download
    try {
      final connectivityService = Provider.of<ConnectivityService>(
        context,
        listen: false,
      );
      final isOnline = await connectivityService.checkConnectivity();

      if (!isOnline) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'You\'re offline. Please connect to the internet to download resources.',
            ),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 3),
            action: SnackBarAction(
              label: 'DISMISS',
              textColor: Colors.white,
              onPressed: () {
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
              },
            ),
          ),
        );
        return;
      }

      // Initialize progress
      setState(() {
        _downloadProgress[resource.id] = 0.0;
      });

      // Create the downloads directory if it doesn't exist
      final appDir = await getApplicationDocumentsDirectory();
      final downloadsDir = Directory('${appDir.path}/EduConnect/Downloads');
      if (!await downloadsDir.exists()) {
        await downloadsDir.create(recursive: true);
      }

      // Extract the original filename from the URL
      final uri = Uri.parse(resource.fileUrl);
      String fileName = path.basename(uri.path);

      // If the filename doesn't have an extension from the URL, try to add one based on resource.fileType
      if (!fileName.contains('.')) {
        final extension = _getExtensionFromFileType(resource.fileType);
        fileName = '${resource.id}$extension';
      }

      // Create file path
      final filePath = '${downloadsDir.path}/$fileName';
      final file = File(filePath);

      // Delete the file if it already exists
      if (await file.exists()) {
        await file.delete();
      }

      // Download the file with progress reporting
      final response = await http.Client().send(http.Request('GET', uri));
      final contentLength = response.contentLength ?? 0;

      final sink = file.openWrite();
      int bytesReceived = 0;

      await response.stream.listen((List<int> chunk) {
        sink.add(chunk);
        bytesReceived += chunk.length;

        if (contentLength > 0) {
          setState(() {
            _downloadProgress[resource.id] = bytesReceived / contentLength;
          });
        }
      }).asFuture();

      await sink.flush();
      await sink.close();

      // Save the file path
      setState(() {
        _downloadedFiles[resource.id] = filePath;
        _downloadProgress.remove(resource.id);
      });

      // Update the stored list of downloaded files
      await _saveDownloadedFiles();

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${resource.title} downloaded successfully'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      print('Error downloading file: $e');

      // Remove progress indicator
      setState(() {
        _downloadProgress.remove(resource.id);
      });

      // Show more specific error message based on the type of error
      String errorMessage = 'Failed to download ${resource.title}';
      Color errorColor = Colors.red;

      if (e.toString().contains('SocketException') ||
          e.toString().contains('ClientException') ||
          e.toString().contains('Failed host lookup')) {
        errorMessage =
            'Download failed: You appear to be offline. Please check your internet connection.';
        errorColor = Colors.orange;
      } else if (e.toString().contains('Permission')) {
        errorMessage = 'Download failed: Storage permission denied.';
      } else if (e.toString().contains('404')) {
        errorMessage =
            'Download failed: The file no longer exists on the server.';
      }

      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: errorColor,
          duration: const Duration(seconds: 3),
          action: SnackBarAction(
            label: 'DISMISS',
            textColor: Colors.white,
            onPressed: () {
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
            },
          ),
        ),
      );
    }
  }

  // Add method to open a downloaded file
  Future<void> _openFile(ResourceModel resource) async {
    try {
      final filePath = _downloadedFiles[resource.id];
      if (filePath == null) {
        throw Exception('File not found');
      }

      final file = File(filePath);
      if (!await file.exists()) {
        throw Exception('File no longer exists');
      }

      final result = await OpenFilex.open(filePath);
      if (result.type != ResultType.done) {
        throw Exception('Could not open file: ${result.message}');
      }
    } catch (e) {
      print('Error opening file: $e');

      // Remove from downloaded files if it doesn't exist
      if (e.toString().contains('no longer exists') ||
          e.toString().contains('not found')) {
        setState(() {
          _downloadedFiles.remove(resource.id);
        });
        await _saveDownloadedFiles();
      }

      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to open file: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  // Helper method to get file extension from file type
  String _getExtensionFromFileType(String fileType) {
    switch (fileType.toLowerCase()) {
      case 'pdf':
        return '.pdf';
      case 'word':
        return '.docx';
      case 'excel':
        return '.xlsx';
      case 'powerpoint':
        return '.pptx';
      case 'image':
        return '.jpg';
      case 'text':
        return '.txt';
      default:
        return '';
    }
  }

  // Load downloaded assignments info
  Future<void> _loadDownloadedAssignments() async {
    try {
      final downloadedAssignments =
          await globalDownloadManager.loadDownloadedAssignments();
      setState(() {
        _downloadedAssignments = downloadedAssignments;
      });
    } catch (e) {
      print('Error loading downloaded assignments: $e');
    }
  }

  // Save downloaded assignments info
  Future<void> _saveDownloadedAssignments() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // Save to global storage instead of per-class storage
      await prefs.setString(
        'downloaded_assignments_all',
        json.encode(_downloadedAssignments),
      );
    } catch (e) {
      print('Error saving downloaded assignments: $e');
    }
  }

  // Add method to download an assignment file
  Future<void> _downloadAssignmentFile(AssignmentModel assignment) async {
    if (_assignmentDownloadProgress.containsKey(assignment.id) ||
        assignment.fileUrl == null) {
      return; // Already downloading or no file URL
    }

    // Check connectivity before attempting download
    try {
      final connectivityService = Provider.of<ConnectivityService>(
        context,
        listen: false,
      );
      final isOnline = await connectivityService.checkConnectivity();

      if (!isOnline) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'You\'re offline. Please connect to the internet to download assignments.',
              ),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 3),
              action: SnackBarAction(
                label: 'DISMISS',
                textColor: Colors.white,
                onPressed: () {
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                },
              ),
            ),
          );
        }
        return;
      }

      // Initialize progress
      if (mounted) {
        setState(() {
          _assignmentDownloadProgress[assignment.id] = 0.0;
        });
      }

      // Create the downloads directory if it doesn't exist
      final appDir = await getApplicationDocumentsDirectory();
      final downloadsDir = Directory(
        '${appDir.path}/EduConnect/Downloads/Assignments',
      );
      if (!await downloadsDir.exists()) {
        await downloadsDir.create(recursive: true);
      }

      // Extract the original filename from the URL
      final uri = Uri.parse(assignment.fileUrl!);
      String fileName = path.basename(uri.path);

      // If the filename doesn't have an extension from the URL, try to add one based on resource.fileType
      if (!fileName.contains('.')) {
        final extension = _getExtensionFromFileType(assignment.fileType);
        fileName = '${assignment.id}$extension';
      }

      // Create file path
      final filePath = '${downloadsDir.path}/$fileName';
      final file = File(filePath);

      // Delete the file if it already exists
      if (await file.exists()) {
        await file.delete();
      }

      // Download the file with progress reporting
      final client = http.Client();
      try {
        final request = http.Request('GET', uri);
        final response = await client.send(request);
        final contentLength = response.contentLength ?? 0;

        final sink = file.openWrite();
        int bytesReceived = 0;

        await response.stream.listen((List<int> chunk) {
          sink.add(chunk);
          bytesReceived += chunk.length;

          if (contentLength > 0 && mounted) {
            setState(() {
              _assignmentDownloadProgress[assignment.id] =
                  bytesReceived / contentLength;
            });
          }
        }).asFuture();

        await sink.flush();
        await sink.close();

        // Save the file path
        if (mounted) {
          setState(() {
            _downloadedAssignments[assignment.id] = filePath;
            _assignmentDownloadProgress.remove(assignment.id);
          });
        }

        // Update the stored list of downloaded files
        await _saveDownloadedAssignments();

        // Show success message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${assignment.title} downloaded successfully'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } finally {
        client.close();
      }
    } catch (e) {
      print('Error downloading assignment file: $e');

      // Remove progress indicator
      if (mounted) {
        setState(() {
          _assignmentDownloadProgress.remove(assignment.id);
        });

        // Show more specific error message based on the type of error
        String errorMessage = 'Failed to download assignment';
        Color errorColor = Colors.red;

        if (e.toString().contains('SocketException') ||
            e.toString().contains('ClientException') ||
            e.toString().contains('Failed host lookup')) {
          errorMessage =
              'Download failed: You appear to be offline. Please check your internet connection.';
          errorColor = Colors.orange;
        } else if (e.toString().contains('Permission')) {
          errorMessage = 'Download failed: Storage permission denied.';
        } else if (e.toString().contains('404')) {
          errorMessage =
              'Download failed: The file no longer exists on the server.';
        }

        // Show error message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: errorColor,
            duration: const Duration(seconds: 3),
            action: SnackBarAction(
              label: 'DISMISS',
              textColor: Colors.white,
              onPressed: () {
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
              },
            ),
          ),
        );
      }
    }
  }

  // Add method to open a downloaded assignment file
  Future<void> _openAssignmentFile(AssignmentModel assignment) async {
    try {
      final filePath = _downloadedAssignments[assignment.id];
      if (filePath == null) {
        throw Exception('File not found');
      }

      final file = File(filePath);
      if (!await file.exists()) {
        throw Exception('File no longer exists');
      }

      final result = await OpenFilex.open(filePath);
      if (result.type != ResultType.done) {
        throw Exception('Could not open file: ${result.message}');
      }
    } catch (e) {
      print('Error opening assignment file: $e');

      // Remove from downloaded files if it doesn't exist
      if (e.toString().contains('no longer exists') ||
          e.toString().contains('not found')) {
        setState(() {
          _downloadedAssignments.remove(assignment.id);
        });
        await _saveDownloadedAssignments();
      }

      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to open file: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  // Load downloaded submissions info
  Future<void> _loadDownloadedSubmissions() async {
    try {
      final downloadedSubmissions =
          await globalDownloadManager.loadDownloadedSubmissions();
      setState(() {
        _downloadedSubmissions = downloadedSubmissions;
      });
    } catch (e) {
      print('Error loading downloaded submissions: $e');
    }
  }

  // Save downloaded submissions info
  Future<void> _saveDownloadedSubmissions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // Save to global storage instead of per-class storage
      await prefs.setString(
        'downloaded_submissions_all',
        json.encode(_downloadedSubmissions),
      );
    } catch (e) {
      print('Error saving downloaded submissions: $e');
    }
  }

  // Add method to download a submission file
  Future<void> _downloadSubmissionFile(SubmissionModel submission) async {
    if (_submissionDownloadProgress.containsKey(submission.id) ||
        submission.fileUrl == null) {
      return; // Already downloading or no file URL
    }

    // Check connectivity before attempting download
    try {
      final connectivityService = Provider.of<ConnectivityService>(
        context,
        listen: false,
      );
      final isOnline = await connectivityService.checkConnectivity();

      if (!isOnline) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'You\'re offline. Please connect to the internet to download submissions.',
            ),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 3),
            action: SnackBarAction(
              label: 'DISMISS',
              textColor: Colors.white,
              onPressed: () {
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
              },
            ),
          ),
        );
        return;
      }

      // Initialize progress
      setState(() {
        _submissionDownloadProgress[submission.id] = 0.0;
      });

      // Create the downloads directory if it doesn't exist
      final appDir = await getApplicationDocumentsDirectory();
      final downloadsDir = Directory(
        '${appDir.path}/EduConnect/Downloads/Submissions',
      );
      if (!await downloadsDir.exists()) {
        await downloadsDir.create(recursive: true);
      }

      // Extract the original filename from the URL
      final uri = Uri.parse(submission.fileUrl!);
      String fileName = path.basename(uri.path);

      // If the filename doesn't have an extension from the URL, try to add one based on submission.fileType
      if (!fileName.contains('.')) {
        final extension = _getExtensionFromFileType(submission.fileType);
        fileName = '${submission.id}$extension';
      }

      // Create file path
      final filePath = '${downloadsDir.path}/$fileName';
      final file = File(filePath);

      // Delete the file if it already exists
      if (await file.exists()) {
        await file.delete();
      }

      // Download the file with progress reporting
      final response = await http.Client().send(http.Request('GET', uri));
      final contentLength = response.contentLength ?? 0;

      final sink = file.openWrite();
      int bytesReceived = 0;

      await response.stream.listen((List<int> chunk) {
        sink.add(chunk);
        bytesReceived += chunk.length;

        if (contentLength > 0) {
          setState(() {
            _submissionDownloadProgress[submission.id] =
                bytesReceived / contentLength;
          });
        }
      }).asFuture();

      await sink.flush();
      await sink.close();

      // Save the file path
      setState(() {
        _downloadedSubmissions[submission.id] = filePath;
        _submissionDownloadProgress.remove(submission.id);
      });

      // Update the stored list of downloaded files
      await _saveDownloadedSubmissions();

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${submission.studentName}\'s submission downloaded successfully',
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      print('Error downloading submission file: $e');

      // Remove progress indicator
      setState(() {
        _submissionDownloadProgress.remove(submission.id);
      });

      // Show more specific error message based on the type of error
      String errorMessage = 'Failed to download submission';
      Color errorColor = Colors.red;

      if (e.toString().contains('SocketException') ||
          e.toString().contains('ClientException') ||
          e.toString().contains('Failed host lookup')) {
        errorMessage =
            'Download failed: You appear to be offline. Please check your internet connection.';
        errorColor = Colors.orange;
      } else if (e.toString().contains('Permission')) {
        errorMessage = 'Download failed: Storage permission denied.';
      } else if (e.toString().contains('404')) {
        errorMessage =
            'Download failed: The file no longer exists on the server.';
      }

      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: errorColor,
          duration: const Duration(seconds: 3),
          action: SnackBarAction(
            label: 'DISMISS',
            textColor: Colors.white,
            onPressed: () {
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
            },
          ),
        ),
      );
    }
  }

  // Add method to open a submitted assignment file (for students to view their own submission)
  Future<void> _openMySubmissionFile(AssignmentModel assignment) async {
    try {
      final filePath = _downloadedSubmissions[assignment.id];
      if (filePath == null) {
        throw Exception('Submission file not found offline');
      }

      final file = File(filePath);
      if (!await file.exists()) {
        throw Exception('File no longer exists');
      }

      final result = await OpenFilex.open(filePath);
      if (result.type != ResultType.done) {
        throw Exception('Could not open file: ${result.message}');
      }
    } catch (e) {
      print('Error opening my submission file: $e');

      // Remove from downloaded files if it doesn't exist
      if (e.toString().contains('no longer exists') ||
          e.toString().contains('not found')) {
        setState(() {
          _downloadedSubmissions.remove(assignment.id);
        });
        await _saveDownloadedSubmissions();
      }

      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to open file: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  // Download student's own submission file
  Future<void> _downloadMySubmission(AssignmentModel assignment) async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final supabaseService = authProvider.supabaseService;

      // Show downloading indicator
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
              SizedBox(width: 16),
              Text('Fetching your submission...'),
            ],
          ),
          duration: Duration(seconds: 10),
        ),
      );

      // Get the student's submission for this assignment
      final submission = await supabaseService.getStudentSubmission(
        assignmentId: assignment.id,
        studentId: authProvider.currentUser!.id,
      );

      if (submission == null || submission.fileUrl == null) {
        // Clear previous snackbar
        ScaffoldMessenger.of(context).hideCurrentSnackBar();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No submission file found'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      // Clear previous snackbar
      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      // Use global download manager to download the submission
      await globalDownloadManager.downloadSubmission(
        submission: submission,
        onProgressUpdate: (progress) {
          if (mounted) {
            setState(() {
              _submissionDownloadProgress = progress;
            });
          }
        },
        onComplete: (downloads) {
          if (mounted) {
            setState(() {
              _downloadedSubmissions = downloads;
            });
          }
        },
        context: context,
      );
    } catch (e) {
      print('Error downloading my submission: $e');

      // Clear previous snackbar
      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to download submission: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Add method to open a downloaded submission file
  Future<void> _openSubmissionFile(SubmissionModel submission) async {
    try {
      final filePath = _downloadedSubmissions[submission.id];
      if (filePath == null) {
        throw Exception('File not found');
      }

      final file = File(filePath);
      if (!await file.exists()) {
        throw Exception('File no longer exists');
      }

      final result = await OpenFilex.open(filePath);
      if (result.type != ResultType.done) {
        throw Exception('Could not open file: ${result.message}');
      }
    } catch (e) {
      print('Error opening submission file: $e');

      // Remove from downloaded files if it doesn't exist
      if (e.toString().contains('no longer exists') ||
          e.toString().contains('not found')) {
        setState(() {
          _downloadedSubmissions.remove(submission.id);
        });
        await _saveDownloadedSubmissions();
      }

      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to open file: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final isLecturer = authProvider.isLecturer;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
        title: ShaderMask(
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
            widget.classModel.name,
            style: GoogleFonts.inter(
              fontWeight: FontWeight.bold,
              fontSize: 22,
              color: Colors.white,
            ),
          ),
        ),
        centerTitle: true,
        iconTheme: IconThemeData(
          color:
              isDark
                  ? AppTheme.darkSecondaryStart
                  : AppTheme.lightSecondaryStart,
        ),
        actions: [
          // Add action button based on user role
          Theme(
            data: Theme.of(context).copyWith(
              popupMenuTheme: PopupMenuThemeData(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28),
                ),
              ),
            ),
            child: PopupMenuButton<String>(
              icon: Icon(
                Icons.more_vert_outlined,
                color:
                    isDark
                        ? AppTheme.darkPrimaryStart
                        : AppTheme.lightPrimaryStart,
              ),
              onSelected: (value) {
                if (value == 'leave') {
                  _leaveClass();
                } else if (value == 'delete') {
                  _deleteClass();
                } else if (value == 'details') {
                  _showClassDetails();
                }
              },
              itemBuilder:
                  (context) => [
                    PopupMenuItem(
                      value: 'details',
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color:
                                isDark
                                    ? AppTheme.darkPrimaryStart
                                    : AppTheme.lightPrimaryStart,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Text('Class Details', style: GoogleFonts.inter()),
                        ],
                      ),
                    ),
                    if (isLecturer)
                      PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            const Icon(
                              Icons.delete_outline,
                              color: Colors.red,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Text('Delete Class', style: GoogleFonts.inter()),
                          ],
                        ),
                      )
                    else
                      PopupMenuItem(
                        value: 'leave',
                        child: Row(
                          children: [
                            const Icon(
                              Icons.exit_to_app,
                              color: Colors.red,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Text('Leave Class', style: GoogleFonts.inter()),
                          ],
                        ),
                      ),
                  ],
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(72),
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
              border: Border(
                bottom: BorderSide(
                  color:
                      isDark
                          ? AppTheme.darkTextSecondary.withOpacity(0.1)
                          : AppTheme.lightTextSecondary.withOpacity(0.1),
                ),
              ),
            ),
            child: TabBar(
              controller: _tabController,
              labelStyle: GoogleFonts.inter(
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
              unselectedLabelStyle: GoogleFonts.inter(
                fontWeight: FontWeight.normal,
                fontSize: 12,
              ),
              labelColor:
                  isDark
                      ? AppTheme.darkSecondaryStart
                      : AppTheme.lightSecondaryStart,
              unselectedLabelColor:
                  isDark
                      ? AppTheme.darkTextSecondary
                      : AppTheme.lightTextSecondary,
              indicatorColor:
                  isDark
                      ? AppTheme.darkSecondaryStart
                      : AppTheme.lightSecondaryStart,
              indicatorWeight: 3,
              indicatorSize: TabBarIndicatorSize.label,
              tabs: [
                Tab(
                  height: 56,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.announcement_outlined, size: 24),
                      const SizedBox(height: 4),
                      const Text('Updates'),
                    ],
                  ),
                ),
                Tab(
                  height: 56,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.folder_outlined, size: 24),
                      const SizedBox(height: 4),
                      const Text('Resources'),
                    ],
                  ),
                ),
                Tab(
                  height: 56,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.assignment_outlined, size: 24),
                      const SizedBox(height: 4),
                      const Text('Assignments'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      // Add floating action button for lecturers to create announcements, upload resources, or create assignments
      floatingActionButton:
          isLecturer
              ? Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
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
                  ),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
                    width: 1,
                  ),
                ),
                child: FloatingActionButton(
                  onPressed: () {
                    if (_tabController.index == 0) {
                      _createAnnouncement();
                    } else if (_tabController.index == 1) {
                      _uploadResource();
                    } else {
                      _createAssignment();
                    }
                  },
                  tooltip:
                      _tabController.index == 0
                          ? 'Add Announcement'
                          : _tabController.index == 1
                          ? 'Upload Resource'
                          : 'Create Assignment',
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  child: Icon(
                    _tabController.index == 0
                        ? Icons.post_add_outlined
                        : _tabController.index == 1
                        ? Icons.upload_file_outlined
                        : Icons.add_task_outlined,
                    color: Colors.white,
                  ),
                ),
              )
              : null,
      body: TabBarView(
        controller: _tabController,
        children: [
          // Announcements Tab
          _buildAnnouncementsTab(context, isLecturer),

          // Resources Tab
          _buildResourcesTab(context, isLecturer),

          // Assignments Tab
          _buildAssignmentsTab(context, isLecturer),
        ],
      ),
    );
  }

  Widget _buildAnnouncementsTab(BuildContext context, bool isLecturer) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return RefreshIndicator(
      onRefresh: _loadAnnouncements,
      displacement: 40.0,
      color: isDark ? AppTheme.darkPrimaryStart : AppTheme.lightPrimaryStart,
      backgroundColor: isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
      strokeWidth: 3.0,
      child:
          _isLoadingAnnouncements && _announcements.isEmpty
              ? Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(
                    isDark
                        ? AppTheme.darkPrimaryStart
                        : AppTheme.lightPrimaryStart,
                  ),
                ),
              )
              : _announcements.isEmpty
              ? _buildEmptyState(
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
                itemCount: _announcements.length,
                physics: const AlwaysScrollableScrollPhysics(),
                itemBuilder: (context, index) {
                  final announcement = _announcements[index];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => _showAnnouncementDetails(announcement),
                        onLongPress:
                            isLecturer
                                ? () => _showAnnouncementOptions(announcement)
                                : null,
                        borderRadius: BorderRadius.circular(28),
                        child: Container(
                          decoration: BoxDecoration(
                            color: isDark ? AppTheme.darkSurface : Colors.white,
                            borderRadius: BorderRadius.circular(28),
                            border: Border.all(
                              color:
                                  isDark
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
                                  Text(
                                    DateFormat(
                                      'MMM d',
                                    ).format(announcement.createdAt),
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
                                    DateFormat(
                                      'h:mm a',
                                    ).format(announcement.createdAt),
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
                                      colors: [
                                        Colors.white,
                                        Colors.white.withOpacity(0.8),
                                      ],
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
                },
              ),
    );
  }

  void _showAnnouncementDetails(AnnouncementModel announcement) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (context) => Container(
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.darkSurface : Colors.white,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  decoration: BoxDecoration(
                    color:
                        isDark
                            ? AppTheme.darkSecondaryStart
                            : AppTheme.lightSecondaryStart,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(28),
                    ),
                  ),
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.announcement_outlined,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ShaderMask(
                              shaderCallback:
                                  (bounds) => LinearGradient(
                                    colors: [
                                      Colors.white,
                                      Colors.white.withOpacity(0.8),
                                    ],
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
                            const SizedBox(height: 4),
                            Text(
                              _getFormattedDate(announcement.createdAt),
                              style: GoogleFonts.inter(
                                color: Colors.white.withOpacity(0.8),
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close, color: Colors.white),
                      ),
                    ],
                  ),
                ),

                // Content
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color:
                                (isDark ? AppTheme.darkSurface : Colors.white),
                            borderRadius: BorderRadius.circular(28),
                            border: Border.all(
                              color:
                                  isDark
                                      ? AppTheme.darkBorder
                                      : AppTheme.lightBorder,
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
                                announcement.postedByName
                                    .substring(0, 1)
                                    .toUpperCase(),
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
                                    color:
                                        isDark
                                            ? Colors.white60
                                            : Colors.black45,
                                  ),
                                ),
                                Text(
                                  announcement.postedByName,
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color:
                                        isDark ? Colors.white : Colors.black87,
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
                const SizedBox(height: 16),
              ],
            ),
          ),
    );
  }

  Widget _buildResourcesTab(BuildContext context, bool isLecturer) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return RefreshIndicator(
      onRefresh: _loadResources,
      displacement: 40.0,
      color: isDark ? AppTheme.darkPrimaryStart : AppTheme.lightPrimaryStart,
      backgroundColor: isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
      strokeWidth: 3.0,
      child:
          _isLoadingResources && _resources.isEmpty
              ? Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(
                    isDark
                        ? AppTheme.darkPrimaryStart
                        : AppTheme.lightPrimaryStart,
                  ),
                ),
              )
              : _resources.isEmpty
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
                itemCount: _resources.length,
                itemBuilder: (context, index) {
                  final resource = _resources[index];
                  final bool isDownloading = _downloadProgress.containsKey(
                    resource.id,
                  );
                  final bool isDownloaded = _downloadedFiles.containsKey(
                    resource.id,
                  );

                  return Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: isDownloaded ? () => _openFile(resource) : null,
                        onLongPress:
                            isLecturer
                                ? () => _showResourceOptions(resource)
                                : null,
                        borderRadius: BorderRadius.circular(28),
                        child: Container(
                          decoration: BoxDecoration(
                            color: isDark ? AppTheme.darkSurface : Colors.white,
                            borderRadius: BorderRadius.circular(28),
                            border: Border.all(
                              color:
                                  isDark
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
                                      color: _getFileColor(
                                        resource.fileType,
                                      ).withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Icon(
                                      _getFileIconData(resource.fileType),
                                      color: _getFileColor(resource.fileType),
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
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
                                                    : AppTheme
                                                        .lightTextSecondary,
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
                                              valueColor:
                                                  AlwaysStoppedAnimation<Color>(
                                                    isDark
                                                        ? AppTheme
                                                            .darkSecondaryStart
                                                        : AppTheme
                                                            .lightSecondaryStart,
                                                  ),
                                              value:
                                                  _downloadProgress[resource
                                                      .id],
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            '${(_downloadProgress[resource.id]! * 100).toStringAsFixed(0)}%',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color:
                                                  isDark
                                                      ? AppTheme
                                                          .darkSecondaryStart
                                                      : AppTheme
                                                          .lightSecondaryStart,
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
                                  if (resource.fileUrl != null) ...[
                                    Icon(
                                      _getFileIconData(resource.fileType),
                                      size: 16,
                                      color:
                                          isDark
                                              ? AppTheme.darkTextSecondary
                                              : AppTheme.lightTextSecondary,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Has attachment',
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
                                    // Added Expanded to make the middle section flexible
                                    child: Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 12,
                                          backgroundColor: (isDark
                                                  ? AppTheme.darkSecondaryStart
                                                  : AppTheme
                                                      .lightSecondaryStart)
                                              .withOpacity(0.1),
                                          child: Text(
                                            resource.uploadedByName[0]
                                                .toUpperCase(),
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                              color:
                                                  isDark
                                                      ? AppTheme
                                                          .darkSecondaryStart
                                                      : AppTheme
                                                          .lightSecondaryStart,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Flexible(
                                          // Added Flexible to allow text to wrap if needed
                                          child: Text(
                                            'Uploaded by ${resource.uploadedByName}',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color:
                                                  isDark
                                                      ? AppTheme
                                                          .darkTextSecondary
                                                      : AppTheme
                                                          .lightTextSecondary,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (!isDownloaded && !isDownloading)
                                    TextButton.icon(
                                      icon: const Icon(
                                        Icons.download,
                                        size: 16,
                                      ),
                                      label: const Text('Download'),
                                      onPressed: () => _downloadFile(resource),
                                      style: TextButton.styleFrom(
                                        foregroundColor:
                                            isDark
                                                ? AppTheme.darkSecondaryStart
                                                : AppTheme.lightSecondaryStart,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ), // Reduced horizontal padding
                                      ),
                                    )
                                  else if (isDownloaded)
                                    TextButton.icon(
                                      icon: const Icon(
                                        Icons.open_in_new,
                                        size: 16,
                                      ),
                                      label: const Text('Open'),
                                      onPressed: () => _openFile(resource),
                                      style: TextButton.styleFrom(
                                        foregroundColor:
                                            isDark
                                                ? AppTheme.darkSecondaryStart
                                                : AppTheme.lightSecondaryStart,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ), // Reduced horizontal padding
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
                },
              ),
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

  Icon _getFileIcon(String fileType) {
    switch (fileType) {
      case 'PDF':
        return Icon(Icons.picture_as_pdf, color: Colors.red);
      case 'Word':
        return Icon(Icons.description, color: Colors.blue);
      case 'Excel':
        return Icon(Icons.table_chart, color: Colors.green);
      case 'PowerPoint':
        return Icon(Icons.slideshow, color: Colors.orange);
      case 'Image':
        return Icon(Icons.image, color: Colors.purple);
      case 'Text':
        return Icon(Icons.article, color: Colors.grey);
      default:
        return Icon(Icons.insert_drive_file, color: Colors.grey);
    }
  }

  Widget _buildInfoRow(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Theme.of(context).primaryColor),
          const SizedBox(width: 8),
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(value)),
        ],
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

  // Method to show resource details
  void _showResourceInfoDialog(BuildContext context, ResourceModel resource) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(resource.title),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ListTile(
                  leading: const Icon(Icons.description),
                  title: const Text('File Type'),
                  subtitle: Text(resource.fileType),
                  contentPadding: EdgeInsets.zero,
                ),
                ListTile(
                  leading: const Icon(Icons.person),
                  title: const Text('Uploaded By'),
                  subtitle: Text(resource.uploadedByName),
                  contentPadding: EdgeInsets.zero,
                ),
                ListTile(
                  leading: const Icon(Icons.calendar_today),
                  title: const Text('Date Uploaded'),
                  subtitle: Text(
                    DateFormat('MMMM d, yyyy').format(resource.createdAt),
                  ),
                  contentPadding: EdgeInsets.zero,
                ),
                if (_downloadedFiles.containsKey(resource.id))
                  ListTile(
                    leading: const Icon(
                      Icons.check_circle,
                      color: Colors.green,
                    ),
                    title: const Text('Status'),
                    subtitle: const Text('Downloaded'),
                    contentPadding: EdgeInsets.zero,
                  ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
            ],
          ),
    );
  }

  // Add helper method for file color based on type
  Color _getFileColor(String fileType) {
    switch (fileType) {
      case 'PDF':
        return Colors.red;
      case 'Word':
        return Colors.blue;
      case 'Excel':
        return Colors.green;
      case 'PowerPoint':
        return Colors.orange;
      case 'Image':
        return Colors.purple;
      case 'Text':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  // Create a new assignment (for lecturers)
  Future<void> _createAssignment() async {
    final formKey = GlobalKey<FormState>();
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    final deadlineDate = ValueNotifier<DateTime>(
      DateTime.now().add(const Duration(days: 7)),
    );
    File? selectedFile;
    String? fileName;
    bool isUploading = false;
    bool sendSms = true; // Default to true

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setModalState) => Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color:
                        Theme.of(context).brightness == Brightness.dark
                            ? AppTheme.darkSurface
                            : Colors.white,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(28),
                    ),
                    border: Border.all(
                      color:
                          Theme.of(context).brightness == Brightness.dark
                              ? AppTheme.darkBorder
                              : AppTheme.lightBorder,
                    ),
                  ),
                  padding: EdgeInsets.only(
                    bottom: MediaQuery.of(context).viewInsets.bottom,
                    left: 16,
                    right: 16,
                    top: 16,
                  ),
                  child: SingleChildScrollView(
                    child: Form(
                      key: formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          ShaderMask(
                            shaderCallback:
                                (bounds) => LinearGradient(
                                  colors:
                                      Theme.of(context).brightness ==
                                              Brightness.dark
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
                              'Create Assignment',
                              style: GoogleFonts.inter(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          TextFormField(
                            controller: titleController,
                            decoration: InputDecoration(
                              labelText: 'Title',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(28),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(28),
                                borderSide: BorderSide(
                                  color:
                                      Theme.of(context).brightness ==
                                              Brightness.dark
                                          ? AppTheme.darkBorder
                                          : AppTheme.lightBorder,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(28),
                                borderSide: BorderSide(
                                  color:
                                      Theme.of(context).brightness ==
                                              Brightness.dark
                                          ? AppTheme.darkSecondaryStart
                                          : AppTheme.lightSecondaryStart,
                                  width: 2,
                                ),
                              ),
                            ),
                            style: GoogleFonts.inter(),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter a title';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: descriptionController,
                            decoration: InputDecoration(
                              labelText: 'Description (Optional)',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(28),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(28),
                                borderSide: BorderSide(
                                  color:
                                      Theme.of(context).brightness ==
                                              Brightness.dark
                                          ? AppTheme.darkBorder
                                          : AppTheme.lightBorder,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(28),
                                borderSide: BorderSide(
                                  color:
                                      Theme.of(context).brightness ==
                                              Brightness.dark
                                          ? AppTheme.darkSecondaryStart
                                          : AppTheme.lightSecondaryStart,
                                  width: 2,
                                ),
                              ),
                              alignLabelWithHint: true,
                            ),
                            style: GoogleFonts.inter(),
                            maxLines: 5,
                          ),
                          const SizedBox(height: 16),
                          // Deadline picker
                          Container(
                            decoration: BoxDecoration(
                              border: Border.all(
                                color:
                                    Theme.of(context).brightness ==
                                            Brightness.dark
                                        ? AppTheme.darkBorder
                                        : AppTheme.lightBorder,
                              ),
                              borderRadius: BorderRadius.circular(28),
                              color:
                                  Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? AppTheme.darkSurface.withOpacity(0.3)
                                      : Colors.grey.shade50,
                            ),
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  'Submission Deadline',
                                  style: GoogleFonts.inter(
                                    fontWeight: FontWeight.bold,
                                    color:
                                        Theme.of(context).brightness ==
                                                Brightness.dark
                                            ? AppTheme.darkSecondaryStart
                                            : AppTheme.lightSecondaryStart,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                ValueListenableBuilder<DateTime>(
                                  valueListenable: deadlineDate,
                                  builder: (context, date, _) {
                                    return Row(
                                      children: [
                                        Text(
                                          DateFormat(
                                            'MMM d, yyyy • h:mm a',
                                          ).format(date),
                                          style: GoogleFonts.inter(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        const Spacer(),
                                        TextButton.icon(
                                          icon: Icon(
                                            Icons.calendar_month_outlined,
                                            color:
                                                Theme.of(context).brightness ==
                                                        Brightness.dark
                                                    ? AppTheme
                                                        .darkSecondaryStart
                                                    : AppTheme
                                                        .lightSecondaryStart,
                                          ),
                                          label: Text(
                                            'Change',
                                            style: GoogleFonts.inter(
                                              fontWeight: FontWeight.w500,
                                              color:
                                                  Theme.of(
                                                            context,
                                                          ).brightness ==
                                                          Brightness.dark
                                                      ? AppTheme
                                                          .darkSecondaryStart
                                                      : AppTheme
                                                          .lightSecondaryStart,
                                            ),
                                          ),
                                          onPressed: () async {
                                            final newDate =
                                                await showDatePicker(
                                                  context: context,
                                                  initialDate: date,
                                                  firstDate: DateTime.now(),
                                                  lastDate: DateTime.now().add(
                                                    const Duration(days: 365),
                                                  ),
                                                );

                                            if (newDate != null) {
                                              final newTime =
                                                  await showTimePicker(
                                                    context: context,
                                                    initialTime:
                                                        TimeOfDay.fromDateTime(
                                                          date,
                                                        ),
                                                  );

                                              if (newTime != null) {
                                                setModalState(() {
                                                  deadlineDate.value = DateTime(
                                                    newDate.year,
                                                    newDate.month,
                                                    newDate.day,
                                                    newTime.hour,
                                                    newTime.minute,
                                                  );
                                                });
                                              }
                                            }
                                          },
                                        ),
                                      ],
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          // File picker (optional)
                          Container(
                            decoration: BoxDecoration(
                              border: Border.all(
                                color:
                                    Theme.of(context).brightness ==
                                            Brightness.dark
                                        ? AppTheme.darkBorder
                                        : AppTheme.lightBorder,
                              ),
                              borderRadius: BorderRadius.circular(28),
                              color:
                                  Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? AppTheme.darkSurface.withOpacity(0.3)
                                      : Colors.grey.shade50,
                            ),
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  'Attachment (Optional)',
                                  style: GoogleFonts.inter(
                                    fontWeight: FontWeight.bold,
                                    color:
                                        Theme.of(context).brightness ==
                                                Brightness.dark
                                            ? AppTheme.darkSecondaryStart
                                            : AppTheme.lightSecondaryStart,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                ElevatedButton.icon(
                                  icon: const Icon(Icons.attach_file_outlined),
                                  label: const Text('Select File'),
                                  onPressed: () async {
                                    try {
                                      // Use file_selector to pick files
                                      final XTypeGroup allFiles = XTypeGroup(
                                        label: 'All Files',
                                        extensions: [
                                          'pdf',
                                          'doc',
                                          'docx',
                                          'ppt',
                                          'pptx',
                                          'txt',
                                          'jpg',
                                          'jpeg',
                                          'png',
                                        ],
                                      );

                                      final XFile? pickedFile = await openFile(
                                        acceptedTypeGroups: [allFiles],
                                      );

                                      if (pickedFile != null) {
                                        final path = pickedFile.path;

                                        // Create the file object
                                        final file = File(path);

                                        // Check if file exists and is readable
                                        if (await file.exists()) {
                                          setModalState(() {
                                            selectedFile = file;
                                            fileName = pickedFile.name;
                                          });
                                        } else {
                                          if (mounted) {
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              const SnackBar(
                                                content: Text(
                                                  'File not found or cannot be accessed',
                                                ),
                                                backgroundColor: Colors.red,
                                              ),
                                            );
                                          }
                                        }
                                      }
                                    } catch (e) {
                                      print("Error picking file: $e");
                                      if (mounted) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              'Error selecting file: $e',
                                            ),
                                            backgroundColor: Colors.red,
                                          ),
                                        );
                                      }
                                    }
                                  },
                                  style: ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 16,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                if (fileName != null) ...[
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.shade50,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(
                                          Icons.description,
                                          color: Colors.blue,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                fileName!,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              if (selectedFile != null)
                                                FutureBuilder<int>(
                                                  future:
                                                      selectedFile!.length(),
                                                  builder: (context, snapshot) {
                                                    if (snapshot.hasData) {
                                                      final kb =
                                                          snapshot.data! / 1024;
                                                      return Text(
                                                        '${kb.toStringAsFixed(1)} KB',
                                                        style: const TextStyle(
                                                          fontSize: 12,
                                                        ),
                                                      );
                                                    }
                                                    return const SizedBox();
                                                  },
                                                ),
                                            ],
                                          ),
                                        ),
                                        IconButton(
                                          icon: const Icon(
                                            Icons.close,
                                            size: 18,
                                          ),
                                          onPressed: () {
                                            setModalState(() {
                                              selectedFile = null;
                                              fileName = null;
                                            });
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),

                          // SMS notification toggle
                          Row(
                            children: [
                              Checkbox(
                                value: sendSms,
                                onChanged: (value) {
                                  setModalState(() {
                                    sendSms = value ?? true;
                                  });
                                },
                              ),
                              const Text('Send SMS notification to students'),
                              const Tooltip(
                                message:
                                    'Students must have added their phone numbers to receive SMS notifications',
                                child: Icon(Icons.info_outline, size: 16),
                              ),
                            ],
                          ),

                          const SizedBox(height: 24),
                          Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors:
                                    Theme.of(context).brightness ==
                                            Brightness.dark
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
                              ),
                              borderRadius: BorderRadius.circular(28),
                              border: Border.all(
                                color:
                                    Theme.of(context).brightness ==
                                            Brightness.dark
                                        ? AppTheme.darkBorder
                                        : AppTheme.lightBorder,
                                width: 1,
                              ),
                            ),
                            child: ElevatedButton(
                              onPressed:
                                  isUploading
                                      ? null
                                      : () async {
                                        if (formKey.currentState!.validate()) {
                                          try {
                                            // Check if file still exists before proceeding
                                            if (selectedFile != null &&
                                                !await selectedFile!.exists()) {
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                const SnackBar(
                                                  content: Text(
                                                    'File no longer exists or cannot be accessed',
                                                  ),
                                                  backgroundColor: Colors.red,
                                                ),
                                              );
                                              return;
                                            }

                                            setModalState(() {
                                              isUploading = true;
                                            });

                                            Navigator.pop(context, {
                                              'title':
                                                  titleController.text.trim(),
                                              'description':
                                                  descriptionController.text
                                                      .trim(),
                                              'deadline': deadlineDate.value,
                                              'file': selectedFile,
                                              'sendSms': sendSms,
                                            });
                                          } catch (e) {
                                            print(
                                              "Error preparing assignment: $e",
                                            );
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  'Error preparing assignment: $e',
                                                ),
                                                backgroundColor: Colors.red,
                                              ),
                                            );
                                            setModalState(() {
                                              isUploading = false;
                                            });
                                          }
                                        }
                                      },
                              style: ElevatedButton.styleFrom(
                                foregroundColor: Colors.white,
                                backgroundColor: Colors.transparent,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(28),
                                ),
                              ),
                              child:
                                  isUploading
                                      ? const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white,
                                            ),
                                          ),
                                          SizedBox(width: 12),
                                          Text('Preparing...'),
                                        ],
                                      )
                                      : Text(
                                        'Create Assignment',
                                        style: GoogleFonts.inter(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ),
                ),
          ),
    ).then((data) async {
      if (data != null && data is Map<String, dynamic>) {
        try {
          setState(() {
            _isLoadingAssignments = true;
          });

          // Show creating indicator
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                  SizedBox(width: 16),
                  Text('Creating assignment...'),
                ],
              ),
              duration: Duration(seconds: 30),
            ),
          );

          final authProvider = Provider.of<AuthProvider>(
            context,
            listen: false,
          );
          final supabaseService = authProvider.supabaseService;

          // Show SMS sending indication
          if (data['sendSms'] == true) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Creating assignment and sending SMS notifications...',
                ),
                duration: Duration(seconds: 2),
              ),
            );
          }

          final assignment = await supabaseService.createAssignment(
            classId: widget.classModel.id,
            title: data['title'],
            description:
                data['description']?.isEmpty ?? true
                    ? null
                    : data['description'],
            deadline: data['deadline'],
            file: data['file'],
            sendSms: data['sendSms'] ?? false,
          );

          setState(() {
            _assignments.insert(0, assignment);
            _isLoadingAssignments = false;
          });

          // Clear previous snackbar
          ScaffoldMessenger.of(context).hideCurrentSnackBar();

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  data['sendSms'] == true
                      ? 'Assignment created and SMS notifications sent'
                      : 'Assignment created successfully',
                ),
                backgroundColor: Colors.green,
              ),
            );
          }
        } catch (e) {
          setState(() {
            _isLoadingAssignments = false;
          });

          // Clear previous snackbar
          ScaffoldMessenger.of(context).hideCurrentSnackBar();

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Failed to create assignment: ${e.toString()}'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      }
    });
  }

  // Submit an assignment (for students)
  Future<void> _submitAssignment(AssignmentModel assignment) async {
    // Check if device is offline first
    bool isOffline = false;
    try {
      final connectivity = Connectivity();
      final connectivityResults = await connectivity.checkConnectivity();
      isOffline =
          !connectivityResults.any(
            (result) => result != ConnectivityResult.none,
          );
    } catch (e) {
      isOffline = true; // Assume offline if connectivity check fails
      print('Error checking connectivity: $e');
    }

    // If offline, show message and return
    if (isOffline) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'You are offline. Please connect to the internet to submit assignments.',
            ),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 3),
            action: SnackBarAction(
              label: 'OK',
              textColor: Colors.white,
              onPressed: () {},
            ),
          ),
        );
      }
      return;
    }

    final formKey = GlobalKey<FormState>();
    File? selectedFile;
    String? fileName;
    bool isUploading = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setModalState) => Padding(
                  padding: EdgeInsets.only(
                    bottom: MediaQuery.of(context).viewInsets.bottom,
                    left: 16,
                    right: 16,
                    top: 16,
                  ),
                  child: SingleChildScrollView(
                    child: Form(
                      key: formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Submit: ${assignment.title}',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          // File picker
                          Container(
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const Text(
                                  'Submission File',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 8),
                                ElevatedButton.icon(
                                  icon: const Icon(Icons.attach_file_outlined),
                                  label: const Text('Select File'),
                                  onPressed: () async {
                                    try {
                                      // Use file_selector to pick files
                                      final XTypeGroup allFiles = XTypeGroup(
                                        label: 'All Files',
                                        extensions: [
                                          'pdf',
                                          'doc',
                                          'docx',
                                          'ppt',
                                          'pptx',
                                          'txt',
                                          'jpg',
                                          'jpeg',
                                          'png',
                                        ],
                                      );

                                      final XFile? pickedFile = await openFile(
                                        acceptedTypeGroups: [allFiles],
                                      );

                                      if (pickedFile != null) {
                                        final path = pickedFile.path;

                                        // Create the file object
                                        final file = File(path);

                                        // Check if file exists and is readable
                                        if (await file.exists()) {
                                          setModalState(() {
                                            selectedFile = file;
                                            fileName = pickedFile.name;
                                          });
                                        } else {
                                          if (mounted) {
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              const SnackBar(
                                                content: Text(
                                                  'File not found or cannot be accessed',
                                                ),
                                                backgroundColor: Colors.red,
                                              ),
                                            );
                                          }
                                        }
                                      }
                                    } catch (e) {
                                      print("Error picking file: $e");
                                      if (mounted) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              'Error selecting file: $e',
                                            ),
                                            backgroundColor: Colors.red,
                                          ),
                                        );
                                      }
                                    }
                                  },
                                  style: ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 16,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                if (fileName != null) ...[
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.shade50,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(
                                          Icons.description,
                                          color: Colors.blue,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                fileName!,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              if (selectedFile != null)
                                                FutureBuilder<int>(
                                                  future:
                                                      selectedFile!.length(),
                                                  builder: (context, snapshot) {
                                                    if (snapshot.hasData) {
                                                      final kb =
                                                          snapshot.data! / 1024;
                                                      return Text(
                                                        '${kb.toStringAsFixed(1)} KB',
                                                        style: const TextStyle(
                                                          fontSize: 12,
                                                        ),
                                                      );
                                                    }
                                                    return const SizedBox();
                                                  },
                                                ),
                                            ],
                                          ),
                                        ),
                                        IconButton(
                                          icon: const Icon(
                                            Icons.close,
                                            size: 18,
                                          ),
                                          onPressed: () {
                                            setModalState(() {
                                              selectedFile = null;
                                              fileName = null;
                                            });
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton(
                            onPressed:
                                isUploading
                                    ? null
                                    : () async {
                                      if (selectedFile == null) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'Please select a file to submit',
                                            ),
                                            backgroundColor: Colors.red,
                                          ),
                                        );
                                        return;
                                      }

                                      try {
                                        // Check if file still exists before proceeding
                                        if (!await selectedFile!.exists()) {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                'File no longer exists or cannot be accessed',
                                              ),
                                              backgroundColor: Colors.red,
                                            ),
                                          );
                                          return;
                                        }

                                        setModalState(() {
                                          isUploading = true;
                                        });

                                        Navigator.pop(context, {
                                          'file': selectedFile,
                                        });
                                      } catch (e) {
                                        print("Error checking file: $e");
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              'Error preparing file: $e',
                                            ),
                                            backgroundColor: Colors.red,
                                          ),
                                        );
                                        setModalState(() {
                                          isUploading = false;
                                        });
                                      }
                                    },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child:
                                  isUploading
                                      ? const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white,
                                            ),
                                          ),
                                          SizedBox(width: 12),
                                          Text('Submitting...'),
                                        ],
                                      )
                                      : const Text('Submit Assignment'),
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ),
                ),
          ),
    ).then((data) async {
      if (data != null && data is Map<String, dynamic>) {
        try {
          // Show uploading indicator
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                  SizedBox(width: 16),
                  Text('Submitting assignment...'),
                ],
              ),
              duration: Duration(seconds: 30),
            ),
          );

          final authProvider = Provider.of<AuthProvider>(
            context,
            listen: false,
          );
          final supabaseService = authProvider.supabaseService;

          await supabaseService.submitAssignment(
            assignmentId: assignment.id,
            file: data['file'],
          );

          // Update submission status
          setState(() {
            _assignmentSubmissions[assignment.id] = true;
          });

          // Clear previous snackbar
          ScaffoldMessenger.of(context).hideCurrentSnackBar();

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Assignment submitted successfully'),
                backgroundColor: Colors.green,
              ),
            );
          }
        } catch (e) {
          // Clear previous snackbar
          ScaffoldMessenger.of(context).hideCurrentSnackBar();

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Failed to submit assignment: ${e.toString()}'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      }
    });
  }

  // View assignment submissions (for lecturers)
  void _viewSubmissions(AssignmentModel assignment) {
    // Navigate to the submissions screen
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SubmissionsScreen(assignment: assignment),
      ),
    );
  }

  IconData _getFileIconData(String fileType) {
    switch (fileType) {
      case 'PDF':
        return Icons.picture_as_pdf;
      case 'Word':
        return Icons.description;
      case 'Excel':
        return Icons.table_chart;
      case 'PowerPoint':
        return Icons.slideshow;
      case 'Image':
        return Icons.image;
      case 'Text':
        return Icons.article;
      default:
        return Icons.insert_drive_file;
    }
  }

  // Build the assignments tab view
  Widget _buildAssignmentsTab(BuildContext context, bool isLecturer) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return RefreshIndicator(
      onRefresh: _loadAssignments,
      displacement: 40.0,
      color:
          isDark ? AppTheme.darkSecondaryStart : AppTheme.lightSecondaryStart,
      backgroundColor: isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
      strokeWidth: 3.0,
      child:
          _isLoadingAssignments && _assignments.isEmpty
              ? Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(
                    isDark
                        ? AppTheme.darkSecondaryStart
                        : AppTheme.lightSecondaryStart,
                  ),
                ),
              )
              : _assignments.isEmpty
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
                itemCount: _assignments.length,
                itemBuilder: (context, index) {
                  final assignment = _assignments[index];
                  final bool hasSubmitted =
                      _assignmentSubmissions[assignment.id] ?? false;
                  final bool isOverdue = DateTime.now().isAfter(
                    assignment.deadline,
                  );
                  final bool isUpcoming =
                      !isOverdue &&
                      DateTime.now().difference(assignment.deadline).inDays >
                          -3;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap:
                            () =>
                                isLecturer
                                    ? _viewSubmissions(assignment)
                                    : null,
                        onLongPress:
                            isLecturer
                                ? () => _showAssignmentOptions(assignment)
                                : null,
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
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
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
                                                isOverdue &&
                                                        !hasSubmitted &&
                                                        !isLecturer
                                                    ? Colors.red
                                                    : isDark
                                                    ? AppTheme.darkTextSecondary
                                                    : AppTheme
                                                        .lightTextSecondary,
                                            fontWeight:
                                                isOverdue &&
                                                        !hasSubmitted &&
                                                        !isLecturer
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
                                    color:
                                        isDark
                                            ? Colors.white70
                                            : Colors.black54,
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
                                      color:
                                          isDark
                                              ? Colors.white24
                                              : Colors.black12,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: _getFileColor(
                                            assignment.fileType,
                                          ).withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: Icon(
                                          _getFileIconData(assignment.fileType),
                                          color: _getFileColor(
                                            assignment.fileType,
                                          ),
                                          size: 18,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Assignment Document',
                                              style: TextStyle(
                                                fontWeight: FontWeight.w600,
                                                color:
                                                    isDark
                                                        ? Colors.white
                                                        : Colors.black87,
                                              ),
                                            ),
                                            Text(
                                              assignment.fileType,
                                              style: TextStyle(
                                                fontSize: 12,
                                                color:
                                                    isDark
                                                        ? Colors.white60
                                                        : Colors.black45,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (_downloadedAssignments.containsKey(
                                        assignment.id,
                                      ))
                                        TextButton.icon(
                                          icon: const Icon(
                                            Icons.open_in_new,
                                            size: 16,
                                          ),
                                          label: const Text('Open'),
                                          onPressed:
                                              () => _openAssignmentFile(
                                                assignment,
                                              ),
                                          style: TextButton.styleFrom(
                                            foregroundColor:
                                                isDark
                                                    ? AppTheme.darkPrimaryStart
                                                    : AppTheme
                                                        .lightPrimaryStart,
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 4,
                                            ),
                                          ),
                                        )
                                      else if (_assignmentDownloadProgress
                                          .containsKey(assignment.id))
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            SizedBox(
                                              width: 16,
                                              height: 16,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                valueColor:
                                                    AlwaysStoppedAnimation<
                                                      Color
                                                    >(
                                                      isDark
                                                          ? AppTheme
                                                              .darkPrimaryStart
                                                          : AppTheme
                                                              .lightPrimaryStart,
                                                    ),
                                                value:
                                                    _assignmentDownloadProgress[assignment
                                                        .id],
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              '${(_assignmentDownloadProgress[assignment.id]! * 100).toStringAsFixed(0)}%',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color:
                                                    isDark
                                                        ? AppTheme
                                                            .darkPrimaryStart
                                                        : AppTheme
                                                            .lightPrimaryStart,
                                              ),
                                            ),
                                          ],
                                        )
                                      else
                                        TextButton.icon(
                                          icon: const Icon(
                                            Icons.download,
                                            size: 16,
                                          ),
                                          label: const Text('Download'),
                                          onPressed:
                                              () => _downloadAssignmentFile(
                                                assignment,
                                              ),
                                          style: TextButton.styleFrom(
                                            foregroundColor:
                                                isDark
                                                    ? AppTheme.darkPrimaryStart
                                                    : AppTheme
                                                        .lightPrimaryStart,
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
                                      _getFileIconData(assignment.fileType),
                                      size: 16,
                                      color:
                                          isDark
                                              ? Colors.white60
                                              : Colors.black45,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Has attachment',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color:
                                            isDark
                                                ? Colors.white60
                                                : Colors.black45,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                  ],
                                  Expanded(
                                    // Added Expanded to make the middle section flexible
                                    child: Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 12,
                                          backgroundColor: (isDark
                                                  ? AppTheme.darkSecondaryStart
                                                  : AppTheme
                                                      .lightSecondaryStart)
                                              .withOpacity(0.1),
                                          child: Text(
                                            assignment.assignedByName[0]
                                                .toUpperCase(),
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                              color:
                                                  isDark
                                                      ? AppTheme
                                                          .darkSecondaryStart
                                                      : AppTheme
                                                          .lightSecondaryStart,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Flexible(
                                          // Added Flexible to allow text to wrap if needed
                                          child: Text(
                                            'Posted by ${assignment.assignedByName}',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color:
                                                  isDark
                                                      ? Colors.white60
                                                      : Colors.black45,
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
                                          _isOffline
                                              ? 'You need to be online to submit assignments'
                                              : 'Submit your assignment',
                                      child: TextButton.icon(
                                        icon: Icon(
                                          _isOffline
                                              ? Icons.cloud_off
                                              : Icons.upload_file,
                                          size: 16,
                                        ),
                                        label: Text(
                                          _isOffline
                                              ? 'Offline'
                                              : (isOverdue
                                                  ? 'Submit Late'
                                                  : 'Submit'),
                                        ),
                                        onPressed:
                                            _isOffline
                                                ? null
                                                : () => _submitAssignment(
                                                  assignment,
                                                ),
                                        style: TextButton.styleFrom(
                                          foregroundColor:
                                              _isOffline
                                                  ? Colors.grey
                                                  : (isOverdue
                                                      ? Colors.red
                                                      : (isDark
                                                          ? AppTheme
                                                              .darkPrimaryStart
                                                          : AppTheme
                                                              .lightPrimaryStart)),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                        ),
                                      ),
                                    )
                                  else if (!isLecturer && hasSubmitted)
                                    _downloadedSubmissions.containsKey(
                                          assignment.id,
                                        )
                                        ? TextButton.icon(
                                          icon: const Icon(
                                            Icons.open_in_new,
                                            size: 16,
                                          ),
                                          label: const Text('View File'),
                                          onPressed:
                                              () => _openMySubmissionFile(
                                                assignment,
                                              ),
                                          style: TextButton.styleFrom(
                                            foregroundColor:
                                                isDark
                                                    ? AppTheme.darkPrimaryStart
                                                    : AppTheme
                                                        .lightPrimaryStart,
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 4,
                                            ),
                                          ),
                                        )
                                        : Tooltip(
                                          message:
                                              _isOffline
                                                  ? 'Go online to download your submission'
                                                  : 'Download your submission to view offline',
                                          child: TextButton.icon(
                                            icon: Icon(
                                              _isOffline
                                                  ? Icons.cloud_off
                                                  : Icons.download,
                                              size: 16,
                                            ),
                                            label: Text(
                                              _isOffline
                                                  ? 'Offline'
                                                  : 'Download',
                                            ),
                                            onPressed:
                                                _isOffline
                                                    ? null
                                                    : () =>
                                                        _downloadMySubmission(
                                                          assignment,
                                                        ),
                                            style: TextButton.styleFrom(
                                              foregroundColor:
                                                  _isOffline
                                                      ? Colors.grey
                                                      : (isDark
                                                          ? AppTheme
                                                              .darkPrimaryStart
                                                          : AppTheme
                                                              .lightPrimaryStart),
                                              padding:
                                                  const EdgeInsets.symmetric(
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
                                      onPressed:
                                          () => _viewSubmissions(assignment),
                                      style: TextButton.styleFrom(
                                        foregroundColor:
                                            isDark
                                                ? AppTheme.darkPrimaryStart
                                                : AppTheme.lightPrimaryStart,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ), // Reduced horizontal padding
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
                },
              ),
    );
  }

  // Add new method to show class details
  void _showClassDetails() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder:
          (context) => Container(
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  decoration: BoxDecoration(
                    color:
                        isDark
                            ? AppTheme.darkSecondaryStart
                            : AppTheme.lightSecondaryStart,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(28),
                    ),
                  ),
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.class_,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ShaderMask(
                              shaderCallback:
                                  (bounds) => LinearGradient(
                                    colors: [
                                      Colors.white,
                                      Colors.white.withOpacity(0.8),
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ).createShader(bounds),
                              child: Text(
                                widget.classModel.name,
                                style: GoogleFonts.inter(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              widget.classModel.courseCode,
                              style: GoogleFonts.inter(
                                color: Colors.white.withOpacity(0.9),
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close, color: Colors.white),
                      ),
                    ],
                  ),
                ),

                // Content
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      _buildDetailRow(
                        icon: Icons.school,
                        label: 'Level',
                        value: widget.classModel.level,
                        isDark: isDark,
                      ),
                      const SizedBox(height: 16),
                      _buildDetailRow(
                        icon: Icons.people,
                        label: 'Students',
                        value:
                            _isLoadingCount
                                ? 'Loading...'
                                : '$_studentsCount enrolled',
                        isDark: isDark,
                      ),
                      const SizedBox(height: 16),
                      _buildDetailRow(
                        icon: Icons.calendar_today,
                        label: 'Created',
                        value: DateFormat(
                          'MMMM d, yyyy',
                        ).format(widget.classModel.createdAt),
                        isDark: isDark,
                      ),
                      if (widget.classModel.code != null) ...[
                        const SizedBox(height: 24),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color:
                                (isDark ? AppTheme.darkSurface : Colors.white),
                            borderRadius: BorderRadius.circular(28),
                            border: Border.all(
                              color:
                                  isDark
                                      ? AppTheme.darkBorder
                                      : AppTheme.lightBorder,
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
                                                      AppTheme
                                                          .darkSecondaryStart,
                                                      AppTheme.darkSecondaryEnd,
                                                    ]
                                                    : [
                                                      AppTheme
                                                          .lightSecondaryStart,
                                                      AppTheme
                                                          .lightSecondaryEnd,
                                                    ],
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                          ).createShader(bounds),
                                      child: Text(
                                        widget.classModel.code!,
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
                                  Clipboard.setData(
                                    ClipboardData(
                                      text: widget.classModel.code!,
                                    ),
                                  );
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Class code copied to clipboard',
                                      ),
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
                ),
              ],
            ),
          ),
    );
  }

  Widget _buildDetailRow({
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

  void _updateOfflineStatus(bool isOffline) {
    setState(() {
      _isOffline = isOffline;
    });
  }

  // Show submission details for students to view their own submission
  void _showMySubmissionDetails(AssignmentModel assignment) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isSubmissionDownloaded = _downloadedSubmissions.containsKey(
      assignment.id,
    );

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder:
          (context) => Container(
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.darkSurface : Colors.white,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(28),
                    ),
                  ),
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.assignment_turned_in,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Your Submission',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              assignment.title,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.9),
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close, color: Colors.white),
                      ),
                    ],
                  ),
                ),

                // Content
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.green.withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.check_circle,
                                color: Colors.green,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Status',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.green,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  Text(
                                    'Successfully Submitted',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (isSubmissionDownloaded) ...[
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color:
                                (isDark ? AppTheme.darkSurface : Colors.white),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color:
                                  isDark
                                      ? AppTheme.darkBorder
                                      : AppTheme.lightBorder,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: (isDark
                                          ? AppTheme.darkPrimaryStart
                                          : AppTheme.lightPrimaryStart)
                                      .withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  Icons.description,
                                  color:
                                      isDark
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
                                      'Your Submission File',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color:
                                            isDark
                                                ? AppTheme.darkTextSecondary
                                                : AppTheme.lightTextSecondary,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    const Text(
                                      'Available Offline',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              TextButton.icon(
                                icon: const Icon(Icons.open_in_new, size: 16),
                                label: const Text('Open'),
                                onPressed: () {
                                  Navigator.pop(context);
                                  _openMySubmissionFile(assignment);
                                },
                                style: TextButton.styleFrom(
                                  foregroundColor:
                                      isDark
                                          ? AppTheme.darkPrimaryStart
                                          : AppTheme.lightPrimaryStart,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ] else ...[
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.orange.withOpacity(0.3),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.orange.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.cloud_download,
                                  color: Colors.orange,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Submission File',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.orange,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    Text(
                                      _isOffline
                                          ? 'Go online to download your submission'
                                          : 'Download to view offline',
                                      style: const TextStyle(fontSize: 14),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
    );
  }

  // Load submission status for assignments (for students)
  Future<void> _loadSubmissionStatus(List<AssignmentModel> assignments) async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final supabaseService = authProvider.supabaseService;

      // Check submission status for each assignment
      for (final assignment in assignments) {
        try {
          final hasSubmitted = await supabaseService.hasSubmittedAssignment(
            assignment.id,
          );

          if (mounted) {
            setState(() {
              _assignmentSubmissions[assignment.id] = hasSubmitted;
            });
          }
        } catch (e) {
          // If we can't check submission status, assume not submitted
          print('Error checking submission status for ${assignment.id}: $e');
          if (mounted) {
            setState(() {
              _assignmentSubmissions[assignment.id] = false;
            });
          }
        }
      }
    } catch (e) {
      print('Error loading submission status: $e');
    }
  }
}
