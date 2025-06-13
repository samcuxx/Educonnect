import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as path;
import 'package:intl/intl.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../providers/auth_provider.dart';
import '../../utils/app_theme.dart';
import '../../widgets/gradient_container.dart';
import '../../models/class_model.dart';
import '../../models/resource_model.dart';
import '../../models/assignment_model.dart';
import '../../utils/global_download_manager.dart';
import 'package:google_fonts/google_fonts.dart';

class ResourcesTab extends StatefulWidget {
  final Map<String, dynamic>? routeArguments;

  const ResourcesTab({Key? key, this.routeArguments}) : super(key: key);

  @override
  State<ResourcesTab> createState() => _ResourcesTabState();
}

class _ResourcesTabState extends State<ResourcesTab>
    with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  String _selectedView = 'overview'; // overview, resources, assignments

  // Data storage
  List<ClassModel> _classes = [];
  List<ResourceModel> _resources = [];
  List<AssignmentModel> _assignments = [];
  Map<String, List<ResourceModel>> _resourcesByClass = {};
  Map<String, List<AssignmentModel>> _assignmentsByClass = {};

  // Track which classes are expanded
  Set<String> _expandedClasses = {};

  // Loading states
  bool _isLoading = false;
  bool _isInitialLoad = true;
  bool _isOfflineMode = false;
  String? _error;
  String? _lastUpdated;

  // Download tracking
  Map<String, double> _downloadProgress = {};
  Map<String, String> _downloadedFiles = {};
  Map<String, double> _assignmentDownloadProgress = {};
  Map<String, String> _downloadedAssignments = {};

  // Keep alive mixin implementation
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );

    _animationController.forward();

    // Check if we should show a specific view based on route arguments
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkRouteArguments();
    });

    // Load cached data immediately
    _loadFromCache().then((hasCachedData) {
      if (hasCachedData && mounted) {
        setState(() {
          _isInitialLoad = false;
        });
      }

      // Then load all data (which will first check cache, then refresh in background)
      _loadAllData();
    });

    // Set up connectivity listener to detect when we go online/offline
    Connectivity().onConnectivityChanged.listen((connectivityResults) {
      final isOnline = connectivityResults.any(
        (result) => result != ConnectivityResult.none,
      );
      if (mounted) {
        setState(() {
          _isOfflineMode = !isOnline;
        });

        // If we just came back online, refresh data
        if (isOnline && _isOfflineMode) {
          _refreshAll(showLoadingIndicator: false);
        }
      }
    });

    // Load downloaded files info using global download manager
    _loadDownloadedFiles();
    _loadDownloadedAssignments();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  // Toggle class expansion
  void _toggleClassExpansion(String classId) {
    setState(() {
      if (_expandedClasses.contains(classId)) {
        _expandedClasses.remove(classId);
      } else {
        _expandedClasses.add(classId);
      }
    });
  }

  // Rebuild data maps from loaded data
  void _rebuildDataMaps() {
    _resourcesByClass.clear();
    _assignmentsByClass.clear();

    // Group resources by class
    for (final resource in _resources) {
      _resourcesByClass[resource.classId] =
          _resourcesByClass[resource.classId] ?? [];
      _resourcesByClass[resource.classId]!.add(resource);
    }

    // Group assignments by class
    for (final assignment in _assignments) {
      _assignmentsByClass[assignment.classId] =
          _assignmentsByClass[assignment.classId] ?? [];
      _assignmentsByClass[assignment.classId]!.add(assignment);
    }
  }

  // Load all data (classes, resources, assignments)
  Future<void> _loadAllData() async {
    // Only show loading indicator on initial load
    if (_isInitialLoad) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final supabaseService = authProvider.supabaseService;
      final isLecturer = authProvider.isLecturer;

      // Check connectivity status first
      bool isOnline = true;
      try {
        final connectivity = Connectivity();
        final connectivityResults = await connectivity.checkConnectivity();
        isOnline = connectivityResults.any(
          (result) => result != ConnectivityResult.none,
        );
      } catch (e) {
        isOnline = false;
        print('Error checking connectivity: $e');
      }

      // Update offline mode state
      if (mounted) {
        setState(() {
          _isOfflineMode = !isOnline;
        });
      }

      // If offline, load from cache only
      if (!isOnline) {
        final hasCachedData = await _loadFromCache();

        if (mounted) {
          setState(() {
            _isLoading = false;
            if (!hasCachedData) {
              _error =
                  "You're offline. Connect to the internet to load your resources.";
            }
          });
        }
        return;
      }

      // Online: First ensure we have cached data for immediate display
      bool hasCachedData = false;
      if (_classes.isEmpty) {
        hasCachedData = await _loadFromCache();
      } else {
        hasCachedData = true;
      }

      if (hasCachedData && mounted && _isLoading) {
        setState(() {
          _isLoading = false;
        });
      }

      // Now load fresh data from network in the background
      try {
        // Load classes
        List<ClassModel> classes;
        if (isLecturer) {
          classes = await supabaseService.getLecturerClasses();
        } else {
          classes = await supabaseService.getStudentClasses();
        }

        // For each class, load resources
        final resourcesByClass = <String, List<ResourceModel>>{};
        final assignmentsByClass = <String, List<AssignmentModel>>{};
        final allResources = <ResourceModel>[];
        final allAssignments = <AssignmentModel>[];

        for (final classModel in classes) {
          try {
            final resources = await supabaseService.getClassResources(
              classModel.id,
            );
            resourcesByClass[classModel.id] = resources;
            allResources.addAll(resources);
          } catch (e) {
            print('Error loading resources for class ${classModel.id}: $e');
          }

          try {
            final assignments = await supabaseService.getClassAssignments(
              classModel.id,
            );
            assignmentsByClass[classModel.id] = assignments;
            allAssignments.addAll(assignments);
          } catch (e) {
            print('Error loading assignments for class ${classModel.id}: $e');
          }
        }

        // Update cache with the latest data
        await _saveToCache(
          classes,
          allResources,
          allAssignments,
          resourcesByClass,
          assignmentsByClass,
        );

        // If we're still mounted, update UI with fresh data
        if (mounted) {
          setState(() {
            _classes = classes;
            _resources = allResources;
            _assignments = allAssignments;
            _resourcesByClass = resourcesByClass;
            _assignmentsByClass = assignmentsByClass;
            _isLoading = false;
            _isInitialLoad = false;
            _isOfflineMode = false;
            _lastUpdated = DateTime.now().toIso8601String();
          });
        }
      } catch (e) {
        print('Error refreshing data from network: $e');
        // If refresh fails but we have cached data, just show that
        if (hasCachedData && mounted) {
          setState(() {
            _isLoading = false;
          });
        } else if (mounted) {
          setState(() {
            _isLoading = false;
            _error = 'Error loading data: ${e.toString()}';
          });
        }
      }
    } catch (e) {
      // General error handling
      if (mounted) {
        setState(() {
          _isLoading = false;

          if (_classes.isEmpty && _resources.isEmpty && _assignments.isEmpty) {
            if (e.toString().contains('SocketException') ||
                e.toString().contains('ClientException') ||
                e.toString().contains('Failed host lookup')) {
              _error =
                  "You're offline. Connect to the internet to load your resources.";
              _isOfflineMode = true;
            } else {
              _error = 'Error: ${e.toString()}';
            }
          } else {
            // If we have cached data, just update offline status
            if (e.toString().contains('SocketException') ||
                e.toString().contains('ClientException') ||
                e.toString().contains('Failed host lookup')) {
              _isOfflineMode = true;
            }
          }
        });
      }
      print('Error loading data: $e');
    }
  }

  // Load data from cache
  Future<bool> _loadFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Load classes from cache
      final classesJson = prefs.getString('cached_classes');
      if (classesJson != null) {
        final classesList = json.decode(classesJson) as List;
        final classes =
            classesList
                .cast<Map<String, dynamic>>()
                .map((e) => ClassModel.fromJson(e))
                .toList();

        // Load resources from cache
        final resourcesJson = prefs.getString('cached_resources');
        final List<ResourceModel> resources = [];
        if (resourcesJson != null) {
          final resourcesList = json.decode(resourcesJson) as List;
          resources.addAll(
            resourcesList
                .cast<Map<String, dynamic>>()
                .map((e) => ResourceModel.fromJson(e))
                .toList(),
          );
        }

        // Load assignments from cache
        final assignmentsJson = prefs.getString('cached_assignments');
        final List<AssignmentModel> assignments = [];
        if (assignmentsJson != null) {
          final assignmentsList = json.decode(assignmentsJson) as List;
          assignments.addAll(
            assignmentsList
                .cast<Map<String, dynamic>>()
                .map((e) => AssignmentModel.fromJson(e))
                .toList(),
          );
        }

        // Get last update time
        final lastUpdated = prefs.getString('resources_last_updated');

        // Rebuild data maps
        final resourcesByClass = <String, List<ResourceModel>>{};
        final assignmentsByClass = <String, List<AssignmentModel>>{};

        for (final resource in resources) {
          resourcesByClass[resource.classId] =
              resourcesByClass[resource.classId] ?? [];
          resourcesByClass[resource.classId]!.add(resource);
        }

        for (final assignment in assignments) {
          assignmentsByClass[assignment.classId] =
              assignmentsByClass[assignment.classId] ?? [];
          assignmentsByClass[assignment.classId]!.add(assignment);
        }

        setState(() {
          _classes = classes;
          _resources = resources;
          _assignments = assignments;
          _resourcesByClass = resourcesByClass;
          _assignmentsByClass = assignmentsByClass;
          _isLoading = false;
          _isInitialLoad = false;
          _isOfflineMode = true;
          _lastUpdated = lastUpdated;
        });

        return true;
      }

      return false;
    } catch (e) {
      print('Error loading from cache: $e');
      return false;
    }
  }

  // Save data to cache for offline use
  Future<void> _saveToCache(
    List<ClassModel> classes,
    List<ResourceModel> resources,
    List<AssignmentModel> assignments,
    Map<String, List<ResourceModel>> resourcesByClass,
    Map<String, List<AssignmentModel>> assignmentsByClass,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Save classes
      final classesJson = json.encode(classes.map((e) => e.toJson()).toList());
      await prefs.setString('cached_classes', classesJson);

      // Save resources
      final resourcesJson = json.encode(
        resources.map((e) => e.toJson()).toList(),
      );
      await prefs.setString('cached_resources', resourcesJson);

      // Save assignments
      final assignmentsJson = json.encode(
        assignments.map((e) => e.toJson()).toList(),
      );
      await prefs.setString('cached_assignments', assignmentsJson);

      // Save last update timestamp
      await prefs.setString(
        'resources_last_updated',
        DateTime.now().toIso8601String(),
      );

      print('Saved data to cache for offline use');
    } catch (e) {
      print('Error saving to cache: $e');
    }
  }

  // Refresh all data (force refresh from server)
  Future<void> _refreshAll({bool showLoadingIndicator = true}) async {
    if (showLoadingIndicator) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final supabaseService = authProvider.supabaseService;
      final isLecturer = authProvider.isLecturer;

      // Check connectivity status
      bool isOnline = true;
      try {
        final connectivity = Connectivity();
        final connectivityResults = await connectivity.checkConnectivity();
        isOnline = connectivityResults.any(
          (result) => result != ConnectivityResult.none,
        );
      } catch (e) {
        isOnline = false;
        print('Error checking connectivity: $e');
      }

      // Update offline mode state
      if (mounted) {
        setState(() {
          _isOfflineMode = !isOnline;
        });
      }

      // If offline, show error or use cached data
      if (!isOnline) {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });

          if (showLoadingIndicator) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text("You're offline. Showing cached data."),
                backgroundColor: Colors.orange,
                duration: const Duration(seconds: 2),
              ),
            );
          }
        }
        return;
      }

      // Online: load fresh data directly from network
      // Load classes
      List<ClassModel> classes;
      if (isLecturer) {
        classes = await supabaseService.getLecturerClasses();
      } else {
        classes = await supabaseService.getStudentClasses();
      }

      // For each class, load resources
      final resourcesByClass = <String, List<ResourceModel>>{};
      final assignmentsByClass = <String, List<AssignmentModel>>{};
      final allResources = <ResourceModel>[];
      final allAssignments = <AssignmentModel>[];

      for (final classModel in classes) {
        try {
          final resources = await supabaseService.getClassResources(
            classModel.id,
            loadFromCache: false, // Force load from network
          );
          resourcesByClass[classModel.id] = resources;
          allResources.addAll(resources);
        } catch (e) {
          print('Error loading resources for class ${classModel.id}: $e');
        }

        try {
          final assignments = await supabaseService.getClassAssignments(
            classModel.id,
            loadFromCache: false, // Force load from network
          );
          assignmentsByClass[classModel.id] = assignments;
          allAssignments.addAll(assignments);
        } catch (e) {
          print('Error loading assignments for class ${classModel.id}: $e');
        }
      }

      // Update cache with the latest data
      await _saveToCache(
        classes,
        allResources,
        allAssignments,
        resourcesByClass,
        assignmentsByClass,
      );

      // If we're still mounted, update UI with fresh data
      if (mounted) {
        setState(() {
          _classes = classes;
          _resources = allResources;
          _assignments = allAssignments;
          _resourcesByClass = resourcesByClass;
          _assignmentsByClass = assignmentsByClass;
          _isLoading = false;
          _isOfflineMode = false;
          _lastUpdated = DateTime.now().toIso8601String();
        });

        if (showLoadingIndicator) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Resources refreshed successfully"),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      // Handle errors
      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        final isOffline =
            e.toString().contains('SocketException') ||
            e.toString().contains('ClientException') ||
            e.toString().contains('Failed host lookup');

        if (showLoadingIndicator) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                isOffline
                    ? "You're offline. Unable to refresh."
                    : "Error refreshing: ${e.toString()}",
              ),
              backgroundColor: isOffline ? Colors.orange : Colors.red,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
      print('Error refreshing data: $e');
    }
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

  // Download a file using global download manager
  Future<void> _downloadFile(ResourceModel resource) async {
    try {
      // Check connectivity first
      bool isOnline = true;
      try {
        final connectivity = Connectivity();
        final connectivityResults = await connectivity.checkConnectivity();
        isOnline = connectivityResults.any(
          (result) => result != ConnectivityResult.none,
        );
      } catch (e) {
        isOnline = false;
        print('Error checking connectivity: $e');
      }

      // If offline, show error and return
      if (!isOnline) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'You\'re offline. Connect to the internet to download resources.',
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

      // Use global download manager
      await globalDownloadManager.downloadResource(
        resource: resource,
        onProgressUpdate: (progress) {
          if (mounted) {
            setState(() {
              _downloadProgress = progress;
            });
          }
        },
        onComplete: (downloads) {
          if (mounted) {
            setState(() {
              _downloadedFiles = downloads;
            });
          }
        },
        context: context,
      );
    } catch (e) {
      print('Error downloading file: $e');
    }
  }

  // Open a downloaded file
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
      if (e.toString().contains('no longer exists') ||
          e.toString().contains('not found')) {
        setState(() {
          _downloadedFiles.remove(resource.id);
        });
        await _saveDownloadedFiles();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to open file: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  // Download assignment file using global download manager
  Future<void> _downloadAssignmentFile(AssignmentModel assignment) async {
    if (assignment.fileUrl == null) {
      return; // No file URL
    }

    try {
      // Check connectivity first
      bool isOnline = true;
      try {
        final connectivity = Connectivity();
        final connectivityResults = await connectivity.checkConnectivity();
        isOnline = connectivityResults.any(
          (result) => result != ConnectivityResult.none,
        );
      } catch (e) {
        isOnline = false;
        print('Error checking connectivity: $e');
      }

      // If offline, show error and return
      if (!isOnline) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'You\'re offline. Connect to the internet to download assignments.',
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

      // Use global download manager
      await globalDownloadManager.downloadAssignment(
        assignment: assignment,
        onProgressUpdate: (progress) {
          if (mounted) {
            setState(() {
              _assignmentDownloadProgress = progress;
            });
          }
        },
        onComplete: (downloads) {
          if (mounted) {
            setState(() {
              _downloadedAssignments = downloads;
            });
          }
        },
        context: context,
      );
    } catch (e) {
      print('Error downloading assignment: $e');
    }
  }

  // Open assignment file
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
      if (e.toString().contains('no longer exists') ||
          e.toString().contains('not found')) {
        setState(() {
          _downloadedAssignments.remove(assignment.id);
        });
        await _saveDownloadedAssignments();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to open file: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  // Get file extension from file type
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

  // Get file icon data
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

  // Get file color
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

  // Delete handlers (TODO: Implement actual deletion)
  void _handleResourceDelete(ResourceModel resource) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Resource deletion will be implemented')),
    );
  }

  void _handleAssignmentDelete(AssignmentModel assignment) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Assignment deletion will be implemented')),
    );
  }

  // Clear error
  void _clearError() {
    setState(() {
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin

    final authProvider = Provider.of<AuthProvider>(context);
    final isLecturer = authProvider.isLecturer;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return FadeTransition(
      opacity: _fadeAnimation,
      child: SafeArea(
        child: Column(
          children: [
            // Header with navigation
            _buildHeader(context, isLecturer, isDark),

            // Main content
            Expanded(child: _buildContent(context, isLecturer, isDark)),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool isLecturer, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Page title with gradient text
          Row(
            children: [
              ShaderMask(
                shaderCallback:
                    (bounds) => (isLecturer
                            ? AppTheme.secondaryGradient(isDark)
                            : AppTheme.primaryGradient(isDark))
                        .createShader(bounds),
                child: Text(
                  'Resources',
                  style: GoogleFonts.inter(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              const Spacer(),
              if (_isOfflineMode)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange.withOpacity(0.5)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.offline_bolt,
                        size: 14,
                        color: Colors.orange,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Offline',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Colors.orange,
                        ),
                      ),
                    ],
                  ),
                ),
              if (_isLoading)
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      isLecturer
                          ? (isDark
                              ? AppTheme.darkSecondaryStart
                              : AppTheme.lightSecondaryStart)
                          : (isDark
                              ? AppTheme.darkPrimaryStart
                              : AppTheme.lightPrimaryStart),
                    ),
                  ),
                )
              else
                IconButton(
                  icon: const Icon(Icons.refresh_outlined),
                  tooltip: 'Refresh',
                  onPressed: _refreshAll,
                  color:
                      isLecturer
                          ? (isDark
                              ? AppTheme.darkSecondaryStart
                              : AppTheme.lightSecondaryStart)
                          : (isDark
                              ? AppTheme.darkPrimaryStart
                              : AppTheme.lightPrimaryStart),
                ),
            ],
          ),

          if (_isOfflineMode && _lastUpdated != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Showing cached data from ${_formatLastUpdated(_lastUpdated!)}',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.white70 : Colors.black54,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),

          const SizedBox(height: 16),

          // View selector
          Container(
            decoration: BoxDecoration(
              color: isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
                width: 1,
              ),
            ),
            child: Row(
              children: [
                _buildTabButton('overview', 'Overview', isLecturer, isDark),
                _buildTabButton('resources', 'Resources', isLecturer, isDark),
                _buildTabButton(
                  'assignments',
                  'Assignments',
                  isLecturer,
                  isDark,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton(
    String value,
    String label,
    bool isLecturer,
    bool isDark,
  ) {
    final isSelected = _selectedView == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedView = value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            gradient:
                isSelected
                    ? (isLecturer
                        ? AppTheme.secondaryGradient(isDark)
                        : AppTheme.primaryGradient(isDark))
                    : null,
            borderRadius: BorderRadius.circular(28),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              color:
                  isSelected
                      ? Colors.white
                      : (isDark
                          ? AppTheme.darkTextSecondary
                          : AppTheme.lightTextSecondary),
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, bool isLecturer, bool isDark) {
    if (_error != null) {
      return _buildErrorState(context, isLecturer, isDark);
    }

    switch (_selectedView) {
      case 'overview':
        return _buildOverviewContent(context, isLecturer, isDark);
      case 'resources':
        return _buildResourcesContent(context, isLecturer, isDark);
      case 'assignments':
        return _buildAssignmentsContent(context, isLecturer, isDark);
      default:
        return _buildOverviewContent(context, isLecturer, isDark);
    }
  }

  Widget _buildErrorState(BuildContext context, bool isLecturer, bool isDark) {
    final bool isOfflineError =
        _error != null &&
        (_error!.contains("You're offline") ||
            _error!.contains("Failed host lookup") ||
            _error!.contains("SocketException") ||
            _error!.contains("ClientException"));

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isOfflineError ? Icons.wifi_off_rounded : Icons.error_outline,
              size: 64,
              color: isOfflineError ? Colors.orange[300] : Colors.red[300],
            ),
            const SizedBox(height: 16),
            Text(
              isOfflineError ? "You're Offline" : "Something Went Wrong",
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isOfflineError ? Colors.orange[700] : Colors.red[700],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isOfflineError
                  ? "Connect to the internet to view your resources"
                  : _error ?? "An error occurred loading your resources",
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 16,
                color:
                    isDark
                        ? AppTheme.darkTextSecondary
                        : AppTheme.lightTextSecondary,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              icon: Icon(Icons.refresh),
              label: Text(isOfflineError ? "Try Again When Online" : "Retry"),
              onPressed: _refreshAll,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewContent(
    BuildContext context,
    bool isLecturer,
    bool isDark,
  ) {
    return RefreshIndicator(
      onRefresh: _refreshAll,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Statistics cards
            _buildStatsGrid(context, isLecturer, isDark),

            const SizedBox(height: 24),

            // Recent resources and assignments
            if (_resources.isNotEmpty || _assignments.isNotEmpty) ...[
              Text(
                'Recent Activity',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              _buildRecentActivity(context, isLecturer, isDark),
            ] else ...[
              _buildEmptyState(context, isLecturer, isDark),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildResourcesContent(
    BuildContext context,
    bool isLecturer,
    bool isDark,
  ) {
    if (_classes.isEmpty) {
      return _buildEmptyClassesState(context, isLecturer, isDark);
    }

    return RefreshIndicator(
      onRefresh: _refreshAll,
      child: ListView.builder(
        padding: const EdgeInsets.all(16.0),
        itemCount: _classes.length,
        itemBuilder: (context, index) {
          final classModel = _classes[index];
          final resources = _resourcesByClass[classModel.id] ?? [];
          final isExpanded = _expandedClasses.contains(classModel.id);

          return _buildClassDropdown(
            context,
            classModel,
            resources,
            isExpanded,
            isLecturer,
            isDark,
            isResourcesView: true,
          );
        },
      ),
    );
  }

  Widget _buildAssignmentsContent(
    BuildContext context,
    bool isLecturer,
    bool isDark,
  ) {
    if (_classes.isEmpty) {
      return _buildEmptyClassesState(context, isLecturer, isDark);
    }

    return RefreshIndicator(
      onRefresh: _refreshAll,
      child: ListView.builder(
        padding: const EdgeInsets.all(16.0),
        itemCount: _classes.length,
        itemBuilder: (context, index) {
          final classModel = _classes[index];
          final assignments = _assignmentsByClass[classModel.id] ?? [];
          final isExpanded = _expandedClasses.contains(classModel.id);

          return _buildClassDropdown(
            context,
            classModel,
            assignments,
            isExpanded,
            isLecturer,
            isDark,
            isResourcesView: false,
          );
        },
      ),
    );
  }

  Widget _buildStatsGrid(BuildContext context, bool isLecturer, bool isDark) {
    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.2,
      children: [
        _buildStatCard(
          'Classes',
          '${_classes.length}',
          Icons.class_outlined,
          isLecturer,
          isDark,
        ),
        _buildStatCard(
          'Resources',
          '${_resources.length}',
          Icons.folder_outlined,
          isLecturer,
          isDark,
        ),
        _buildStatCard(
          'Assignments',
          '${_assignments.length}',
          Icons.assignment_outlined,
          isLecturer,
          isDark,
        ),
        _buildStatCard(
          'Recent Items',
          '${(_resources.take(5).length + _assignments.take(5).length)}',
          Icons.schedule_outlined,
          isLecturer,
          isDark,
        ),
      ],
    );
  }

  Widget _buildStatCard(
    String title,
    String count,
    IconData icon,
    bool isLecturer,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient:
                  isLecturer
                      ? AppTheme.secondaryGradient(isDark)
                      : AppTheme.primaryGradient(isDark),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
          const Spacer(),
          Text(
            count,
            style: GoogleFonts.inter(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color:
                  isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
            ),
          ),
          Text(
            title,
            style: GoogleFonts.inter(
              color:
                  isDark
                      ? AppTheme.darkTextSecondary
                      : AppTheme.lightTextSecondary,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentActivity(
    BuildContext context,
    bool isLecturer,
    bool isDark,
  ) {
    final recentItems = <Widget>[];

    // Add recent resources
    for (final resource in _resources.take(5)) {
      final classModel = _classes.firstWhere((c) => c.id == resource.classId);
      recentItems.add(
        _buildResourceCard(resource, classModel, isLecturer, isDark),
      );
    }

    // Add recent assignments
    for (final assignment in _assignments.take(5)) {
      final classModel = _classes.firstWhere((c) => c.id == assignment.classId);
      recentItems.add(
        _buildAssignmentCard(assignment, classModel, isLecturer, isDark),
      );
    }

    return Column(children: recentItems.take(10).toList());
  }

  Widget _buildEmptyState(BuildContext context, bool isLecturer, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color:
                  isLecturer
                      ? (isDark
                          ? AppTheme.darkSecondaryStart.withOpacity(0.1)
                          : AppTheme.lightSecondaryStart.withOpacity(0.1))
                      : (isDark
                          ? AppTheme.darkPrimaryStart.withOpacity(0.1)
                          : AppTheme.lightPrimaryStart.withOpacity(0.1)),
              shape: BoxShape.circle,
              border: Border.all(
                color:
                    isLecturer
                        ? (isDark
                            ? AppTheme.darkSecondaryStart.withOpacity(0.3)
                            : AppTheme.lightSecondaryStart.withOpacity(0.3))
                        : (isDark
                            ? AppTheme.darkPrimaryStart.withOpacity(0.3)
                            : AppTheme.lightPrimaryStart.withOpacity(0.3)),
                width: 1,
              ),
            ),
            child: Icon(
              Icons.folder_outlined,
              size: 48,
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
          const SizedBox(height: 24),
          Text(
            'No Resources Yet',
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color:
                  isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            isLecturer
                ? 'Upload resources for your classes to get started'
                : 'Your course resources will appear here',
            style: GoogleFonts.inter(
              fontSize: 14,
              color:
                  isDark
                      ? AppTheme.darkTextSecondary
                      : AppTheme.lightTextSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyClassesState(
    BuildContext context,
    bool isLecturer,
    bool isDark,
  ) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color:
                    isLecturer
                        ? (isDark
                            ? AppTheme.darkSecondaryStart.withOpacity(0.1)
                            : AppTheme.lightSecondaryStart.withOpacity(0.1))
                        : (isDark
                            ? AppTheme.darkPrimaryStart.withOpacity(0.1)
                            : AppTheme.lightPrimaryStart.withOpacity(0.1)),
                shape: BoxShape.circle,
                border: Border.all(
                  color:
                      isLecturer
                          ? (isDark
                              ? AppTheme.darkSecondaryStart.withOpacity(0.3)
                              : AppTheme.lightSecondaryStart.withOpacity(0.3))
                          : (isDark
                              ? AppTheme.darkPrimaryStart.withOpacity(0.3)
                              : AppTheme.lightPrimaryStart.withOpacity(0.3)),
                  width: 1,
                ),
              ),
              child: Icon(
                isLecturer ? Icons.school_outlined : Icons.class_outlined,
                size: 48,
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
            const SizedBox(height: 24),
            Text(
              isLecturer ? 'No Classes Created' : 'No Classes Joined',
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color:
                    isDark
                        ? AppTheme.darkTextPrimary
                        : AppTheme.lightTextPrimary,
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                isLecturer
                    ? 'Create your first class to start sharing resources'
                    : 'Join a class to access resources and assignments',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color:
                      isDark
                          ? AppTheme.darkTextSecondary
                          : AppTheme.lightTextSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Build class dropdown widget for both resources and assignments
  Widget _buildClassDropdown(
    BuildContext context,
    ClassModel classModel,
    List<dynamic> items,
    bool isExpanded,
    bool isLecturer,
    bool isDark, {
    required bool isResourcesView,
  }) {
    final itemsCount = items.length;
    final itemsLabel = isResourcesView ? 'resources' : 'assignments';

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28),
        side: BorderSide(
          color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
          width: 1,
        ),
      ),
      color: isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
      child: Column(
        children: [
          // Header (always visible)
          InkWell(
            borderRadius: BorderRadius.vertical(
              top: const Radius.circular(28),
              bottom: isExpanded ? Radius.zero : const Radius.circular(28),
            ),
            onTap: () => _toggleClassExpansion(classModel.id),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient:
                          isLecturer
                              ? AppTheme.secondaryGradient(isDark)
                              : AppTheme.primaryGradient(isDark),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Icon(
                      isResourcesView
                          ? Icons.folder_outlined
                          : Icons.assignment_outlined,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          classModel.name,
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color:
                                isDark
                                    ? AppTheme.darkTextPrimary
                                    : AppTheme.lightTextPrimary,
                          ),
                        ),
                        Text(
                          classModel.courseCode,
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
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: (isLecturer
                              ? AppTheme.lightSecondaryStart
                              : AppTheme.lightPrimaryStart)
                          .withOpacity(0.1),
                      borderRadius: BorderRadius.circular(28),
                    ),
                    child: Text(
                      '$itemsCount $itemsLabel',
                      style: GoogleFonts.inter(
                        color:
                            isLecturer
                                ? (isDark
                                    ? AppTheme.darkSecondaryStart
                                    : AppTheme.lightSecondaryStart)
                                : (isDark
                                    ? AppTheme.darkPrimaryStart
                                    : AppTheme.lightPrimaryStart),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    isExpanded ? Icons.expand_less : Icons.expand_more,
                    color:
                        isDark
                            ? AppTheme.darkTextSecondary
                            : AppTheme.lightTextSecondary,
                  ),
                ],
              ),
            ),
          ),

          // Content (visible when expanded)
          if (isExpanded)
            Container(
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(28),
                ),
                color: isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
              ),
              child: Column(
                children: [
                  Divider(
                    height: 1,
                    color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
                  ),
                  if (items.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        isResourcesView
                            ? 'No resources uploaded yet'
                            : 'No assignments created yet',
                        style: GoogleFonts.inter(
                          color:
                              isDark
                                  ? AppTheme.darkTextSecondary
                                  : AppTheme.lightTextSecondary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    )
                  else
                    ...items.map((item) {
                      if (isResourcesView) {
                        return _buildResourceCard(
                          item as ResourceModel,
                          classModel,
                          isLecturer,
                          isDark,
                        );
                      } else {
                        return _buildAssignmentCard(
                          item as AssignmentModel,
                          classModel,
                          isLecturer,
                          isDark,
                        );
                      }
                    }).toList(),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildResourceCard(
    ResourceModel resource,
    ClassModel classModel,
    bool isLecturer,
    bool isDark,
  ) {
    final bool isDownloading = _downloadProgress.containsKey(resource.id);
    final bool isDownloaded = _downloadedFiles.containsKey(resource.id);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isDownloaded ? () => _openFile(resource) : null,
          onLongPress:
              isLecturer ? () => _showResourceDeleteOptions(resource) : null,
          borderRadius: BorderRadius.circular(28),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? Colors.black12 : Colors.white,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _getFileColor(resource.fileType).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
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
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        resource.title,
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.bold,
                          color:
                              isDark
                                  ? AppTheme.darkTextPrimary
                                  : AppTheme.lightTextPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${classModel.courseCode} • ${DateFormat('MMM d').format(resource.createdAt)}',
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
                  IconButton(
                    icon: const Icon(Icons.open_in_new_outlined, size: 20),
                    onPressed: () => _openFile(resource),
                    tooltip: 'Open',
                    color:
                        isLecturer
                            ? (isDark
                                ? AppTheme.darkSecondaryStart
                                : AppTheme.lightSecondaryStart)
                            : (isDark
                                ? AppTheme.darkPrimaryStart
                                : AppTheme.lightPrimaryStart),
                  )
                else if (isDownloading)
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      value: _downloadProgress[resource.id],
                      valueColor: AlwaysStoppedAnimation<Color>(
                        isLecturer
                            ? (isDark
                                ? AppTheme.darkSecondaryStart
                                : AppTheme.lightSecondaryStart)
                            : (isDark
                                ? AppTheme.darkPrimaryStart
                                : AppTheme.lightPrimaryStart),
                      ),
                    ),
                  )
                else
                  IconButton(
                    icon: const Icon(Icons.download_outlined, size: 20),
                    onPressed: () => _downloadFile(resource),
                    tooltip: 'Download',
                    color:
                        isLecturer
                            ? (isDark
                                ? AppTheme.darkSecondaryStart
                                : AppTheme.lightSecondaryStart)
                            : (isDark
                                ? AppTheme.darkPrimaryStart
                                : AppTheme.lightPrimaryStart),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAssignmentCard(
    AssignmentModel assignment,
    ClassModel classModel,
    bool isLecturer,
    bool isDark,
  ) {
    final bool isDownloading = _assignmentDownloadProgress.containsKey(
      assignment.id,
    );
    final bool isDownloaded = _downloadedAssignments.containsKey(assignment.id);
    final bool hasFile = assignment.fileUrl != null;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap:
              hasFile && isDownloaded
                  ? () => _openAssignmentFile(assignment)
                  : null,
          onLongPress:
              isLecturer
                  ? () => _showAssignmentDeleteOptions(assignment)
                  : null,
          borderRadius: BorderRadius.circular(28),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? Colors.black12 : Colors.white,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: (hasFile
                            ? _getFileColor(assignment.fileType)
                            : Colors.grey)
                        .withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(
                    hasFile
                        ? _getFileIconData(assignment.fileType)
                        : Icons.assignment_outlined,
                    color:
                        hasFile
                            ? _getFileColor(assignment.fileType)
                            : Colors.grey,
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
                          fontWeight: FontWeight.bold,
                          color:
                              isDark
                                  ? AppTheme.darkTextPrimary
                                  : AppTheme.lightTextPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${classModel.courseCode} • Due ${DateFormat('MMM d').format(assignment.deadline)}',
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
                if (hasFile) ...[
                  if (isDownloaded)
                    IconButton(
                      icon: const Icon(Icons.open_in_new_outlined, size: 20),
                      onPressed: () => _openAssignmentFile(assignment),
                      tooltip: 'Open',
                      color:
                          isLecturer
                              ? (isDark
                                  ? AppTheme.darkSecondaryStart
                                  : AppTheme.lightSecondaryStart)
                              : (isDark
                                  ? AppTheme.darkPrimaryStart
                                  : AppTheme.lightPrimaryStart),
                    )
                  else if (isDownloading)
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        value: _assignmentDownloadProgress[assignment.id],
                        valueColor: AlwaysStoppedAnimation<Color>(
                          isLecturer
                              ? (isDark
                                  ? AppTheme.darkSecondaryStart
                                  : AppTheme.lightSecondaryStart)
                              : (isDark
                                  ? AppTheme.darkPrimaryStart
                                  : AppTheme.lightPrimaryStart),
                        ),
                      ),
                    )
                  else
                    IconButton(
                      icon: const Icon(Icons.download_outlined, size: 20),
                      onPressed: () => _downloadAssignmentFile(assignment),
                      tooltip: 'Download',
                      color:
                          isLecturer
                              ? (isDark
                                  ? AppTheme.darkSecondaryStart
                                  : AppTheme.lightSecondaryStart)
                              : (isDark
                                  ? AppTheme.darkPrimaryStart
                                  : AppTheme.lightPrimaryStart),
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showResourceDeleteOptions(ResourceModel resource) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder:
          (context) => Container(
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.darkSurface : Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.delete, color: Colors.red),
                  title: const Text('Delete Resource'),
                  onTap: () {
                    Navigator.pop(context);
                    _handleResourceDelete(resource);
                  },
                ),
              ],
            ),
          ),
    );
  }

  void _showAssignmentDeleteOptions(AssignmentModel assignment) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder:
          (context) => Container(
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.darkSurface : Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.delete, color: Colors.red),
                  title: const Text('Delete Assignment'),
                  onTap: () {
                    Navigator.pop(context);
                    _handleAssignmentDelete(assignment);
                  },
                ),
              ],
            ),
          ),
    );
  }

  // Format the last updated time for display
  String _formatLastUpdated(String isoString) {
    try {
      final dateTime = DateTime.parse(isoString);
      final now = DateTime.now();
      final difference = now.difference(dateTime);

      if (difference.inDays > 0) {
        return '${difference.inDays} ${difference.inDays == 1 ? 'day' : 'days'} ago';
      } else if (difference.inHours > 0) {
        return '${difference.inHours} ${difference.inHours == 1 ? 'hour' : 'hours'} ago';
      } else if (difference.inMinutes > 0) {
        return '${difference.inMinutes} ${difference.inMinutes == 1 ? 'minute' : 'minutes'} ago';
      } else {
        return 'just now';
      }
    } catch (e) {
      return 'unknown time';
    }
  }

  // Check for route arguments to determine which view to show
  void _checkRouteArguments() {
    // First check widget arguments
    if (widget.routeArguments != null &&
        widget.routeArguments!.containsKey('resourcesView')) {
      final view = widget.routeArguments!['resourcesView'] as String;
      if (mounted) {
        setState(() {
          _selectedView = view;
        });
      }
      return;
    }

    // Fallback to ModalRoute if needed
    final modalRoute = ModalRoute.of(context);
    if (modalRoute != null && modalRoute.settings.arguments != null) {
      final args = modalRoute.settings.arguments as Map<String, dynamic>?;
      if (args != null && args.containsKey('resourcesView')) {
        final view = args['resourcesView'] as String;
        if (mounted) {
          setState(() {
            _selectedView = view;
          });
        }
      }
    }
  }
}
