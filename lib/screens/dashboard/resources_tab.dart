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
import '../../providers/auth_provider.dart';
import '../../utils/app_theme.dart';
import '../../widgets/gradient_container.dart';
import '../../models/class_model.dart';
import '../../models/resource_model.dart';
import '../../models/assignment_model.dart';

class ResourcesTab extends StatefulWidget {
  const ResourcesTab({Key? key}) : super(key: key);

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

  // Loading states
  bool _isLoading = false;
  bool _isInitialLoad = true;
  String? _error;

  // Cache management
  DateTime? _lastCacheUpdate;
  static const Duration _cacheValidDuration = Duration(minutes: 5);
  bool _hasDataLoaded = false;

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

    // Load cached data and check if refresh is needed
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadCachedDataAndRefreshIfNeeded();
    });

    // Load downloaded files info
    _loadDownloadedFiles();
    _loadDownloadedAssignments();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  // Load cached data and refresh if needed
  Future<void> _loadCachedDataAndRefreshIfNeeded() async {
    // Load cached data first
    await _loadCachedData();

    // Check if we need to refresh
    if (_shouldRefreshData()) {
      await _loadAllData(forceRefresh: false);
    }
  }

  // Load cached data from SharedPreferences
  Future<void> _loadCachedData() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Load cache timestamp
      final cacheTimestamp = prefs.getInt('resources_cache_timestamp');
      if (cacheTimestamp != null) {
        _lastCacheUpdate = DateTime.fromMillisecondsSinceEpoch(cacheTimestamp);
      }

      // Load cached classes
      final classesJson = prefs.getString('resources_cache_classes');
      if (classesJson != null) {
        final classesList = json.decode(classesJson) as List;
        _classes =
            classesList.map((json) => ClassModel.fromJson(json)).toList();
      }

      // Load cached resources
      final resourcesJson = prefs.getString('resources_cache_resources');
      if (resourcesJson != null) {
        final resourcesList = json.decode(resourcesJson) as List;
        _resources =
            resourcesList.map((json) => ResourceModel.fromJson(json)).toList();
      }

      // Load cached assignments
      final assignmentsJson = prefs.getString('resources_cache_assignments');
      if (assignmentsJson != null) {
        final assignmentsList = json.decode(assignmentsJson) as List;
        _assignments =
            assignmentsList
                .map((json) => AssignmentModel.fromJson(json))
                .toList();
      }

      // Rebuild maps if we have cached data
      if (_classes.isNotEmpty) {
        _rebuildDataMaps();
        setState(() {
          _hasDataLoaded = true;
          _isInitialLoad = false;
        });
      }
    } catch (e) {
      print('Error loading cached data: $e');
      // If cache loading fails, we'll just refresh from server
    }
  }

  // Save data to cache
  Future<void> _saveCacheData() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Save cache timestamp
      _lastCacheUpdate = DateTime.now();
      await prefs.setInt(
        'resources_cache_timestamp',
        _lastCacheUpdate!.millisecondsSinceEpoch,
      );

      // Save classes
      await prefs.setString(
        'resources_cache_classes',
        json.encode(_classes.map((c) => c.toJson()).toList()),
      );

      // Save resources
      await prefs.setString(
        'resources_cache_resources',
        json.encode(_resources.map((r) => r.toJson()).toList()),
      );

      // Save assignments
      await prefs.setString(
        'resources_cache_assignments',
        json.encode(_assignments.map((a) => a.toJson()).toList()),
      );
    } catch (e) {
      print('Error saving cache data: $e');
    }
  }

  // Check if data should be refreshed
  bool _shouldRefreshData() {
    // Always refresh on initial load if no data
    if (!_hasDataLoaded || _classes.isEmpty) {
      return true;
    }

    // Check if cache is expired
    if (_lastCacheUpdate == null) {
      return true;
    }

    final timeSinceLastUpdate = DateTime.now().difference(_lastCacheUpdate!);
    return timeSinceLastUpdate > _cacheValidDuration;
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
  Future<void> _loadAllData({bool forceRefresh = true}) async {
    // Don't show loading for background refreshes
    if (forceRefresh || _isInitialLoad) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final supabaseService = authProvider.supabaseService;
      final isLecturer = authProvider.isLecturer;

      // Load classes
      final classes =
          isLecturer
              ? await supabaseService.getLecturerClasses()
              : await supabaseService.getStudentClasses();

      // Load resources and assignments for each class
      final resourcesByClass = <String, List<ResourceModel>>{};
      final assignmentsByClass = <String, List<AssignmentModel>>{};
      final allResources = <ResourceModel>[];
      final allAssignments = <AssignmentModel>[];

      for (final classModel in classes) {
        // Load resources for this class
        final classResources = await supabaseService.getClassResources(
          classModel.id,
        );
        resourcesByClass[classModel.id] = classResources;
        allResources.addAll(classResources);

        // Load assignments for this class
        final classAssignments = await supabaseService.getClassAssignments(
          classModel.id,
        );
        assignmentsByClass[classModel.id] = classAssignments;
        allAssignments.addAll(classAssignments);
      }

      setState(() {
        _classes = classes;
        _resources = allResources;
        _assignments = allAssignments;
        _resourcesByClass = resourcesByClass;
        _assignmentsByClass = assignmentsByClass;
        _isLoading = false;
        _hasDataLoaded = true;
        _isInitialLoad = false;
      });

      // Save to cache
      await _saveCacheData();
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
        _isInitialLoad = false;
      });
    }
  }

  // Refresh all data (force refresh from server)
  Future<void> _refreshAll() async {
    await _loadAllData(forceRefresh: true);
  }

  // Smart refresh - only refreshes if cache is expired
  Future<void> _smartRefresh() async {
    if (_shouldRefreshData()) {
      await _loadAllData(forceRefresh: false);
    }
  }

  // Force refresh from server (ignores cache)
  Future<void> _forceRefresh() async {
    await _loadAllData(forceRefresh: true);
  }

  // Clear cache and force refresh
  Future<void> _clearCacheAndRefresh() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('resources_cache_timestamp');
      await prefs.remove('resources_cache_classes');
      await prefs.remove('resources_cache_resources');
      await prefs.remove('resources_cache_assignments');

      _lastCacheUpdate = null;
      _hasDataLoaded = false;

      await _loadAllData(forceRefresh: true);
    } catch (e) {
      print('Error clearing cache: $e');
    }
  }

  // Clear error
  void _clearError() {
    setState(() {
      _error = null;
    });
  }

  // Invalidate cache and refresh (call this when new data is added)
  static void invalidateCache() {
    _invalidateStaticCache();
  }

  static void _invalidateStaticCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('resources_cache_timestamp');
    } catch (e) {
      print('Error invalidating cache: $e');
    }
  }

  // Check if we have valid cached data
  bool get hasValidCache =>
      _lastCacheUpdate != null &&
      DateTime.now().difference(_lastCacheUpdate!) < _cacheValidDuration;

  // Get cache age
  String get cacheAge {
    if (_lastCacheUpdate == null) return 'No cache';

    final age = DateTime.now().difference(_lastCacheUpdate!);
    if (age.inMinutes < 1) {
      return 'Just now';
    } else if (age.inMinutes < 60) {
      return '${age.inMinutes}m ago';
    } else if (age.inHours < 24) {
      return '${age.inHours}h ago';
    } else {
      return '${age.inDays}d ago';
    }
  }

  // Load downloaded files info
  Future<void> _loadDownloadedFiles() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final fileMap = prefs.getString('downloaded_resources_all');

      if (fileMap != null) {
        setState(() {
          _downloadedFiles = Map<String, String>.from(json.decode(fileMap));
        });

        // Verify files still exist
        for (final resourceId in _downloadedFiles.keys.toList()) {
          final filePath = _downloadedFiles[resourceId];
          if (filePath != null) {
            final file = File(filePath);
            if (!await file.exists()) {
              setState(() {
                _downloadedFiles.remove(resourceId);
              });
            }
          }
        }

        // Save changes if any files were removed
        await _saveDownloadedFiles();
      }
    } catch (e) {
      print('Error loading downloaded files: $e');
    }
  }

  // Save downloaded files info
  Future<void> _saveDownloadedFiles() async {
    try {
      final prefs = await SharedPreferences.getInstance();
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
      final prefs = await SharedPreferences.getInstance();
      final fileMap = prefs.getString('downloaded_assignments_all');

      if (fileMap != null) {
        setState(() {
          _downloadedAssignments = Map<String, String>.from(
            json.decode(fileMap),
          );
        });

        // Verify files still exist
        for (final assignmentId in _downloadedAssignments.keys.toList()) {
          final filePath = _downloadedAssignments[assignmentId];
          if (filePath != null) {
            final file = File(filePath);
            if (!await file.exists()) {
              setState(() {
                _downloadedAssignments.remove(assignmentId);
              });
            }
          }
        }

        // Save changes if any files were removed
        await _saveDownloadedAssignments();
      }
    } catch (e) {
      print('Error loading downloaded assignments: $e');
    }
  }

  // Save downloaded assignments info
  Future<void> _saveDownloadedAssignments() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'downloaded_assignments_all',
        json.encode(_downloadedAssignments),
      );
    } catch (e) {
      print('Error saving downloaded assignments: $e');
    }
  }

  // Download a file
  Future<void> _downloadFile(ResourceModel resource) async {
    if (_downloadProgress.containsKey(resource.id)) {
      return; // Already downloading
    }

    try {
      setState(() {
        _downloadProgress[resource.id] = 0.0;
      });

      final appDir = await getApplicationDocumentsDirectory();
      final downloadsDir = Directory('${appDir.path}/EduConnect/Downloads');
      if (!await downloadsDir.exists()) {
        await downloadsDir.create(recursive: true);
      }

      final uri = Uri.parse(resource.fileUrl);
      String fileName = path.basename(uri.path);

      if (!fileName.contains('.')) {
        final extension = _getExtensionFromFileType(resource.fileType);
        fileName = '${resource.id}$extension';
      }

      final filePath = '${downloadsDir.path}/$fileName';
      final file = File(filePath);

      if (await file.exists()) {
        await file.delete();
      }

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

      setState(() {
        _downloadedFiles[resource.id] = filePath;
        _downloadProgress.remove(resource.id);
      });

      await _saveDownloadedFiles();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${resource.title} downloaded successfully'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _downloadProgress.remove(resource.id);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to download ${resource.title}: ${e.toString()}',
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
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

  // Download assignment file
  Future<void> _downloadAssignmentFile(AssignmentModel assignment) async {
    if (_assignmentDownloadProgress.containsKey(assignment.id) ||
        assignment.fileUrl == null) {
      return; // Already downloading or no file URL
    }

    try {
      setState(() {
        _assignmentDownloadProgress[assignment.id] = 0.0;
      });

      final appDir = await getApplicationDocumentsDirectory();
      final downloadsDir = Directory(
        '${appDir.path}/EduConnect/Downloads/Assignments',
      );
      if (!await downloadsDir.exists()) {
        await downloadsDir.create(recursive: true);
      }

      final uri = Uri.parse(assignment.fileUrl!);
      String fileName = path.basename(uri.path);

      if (!fileName.contains('.')) {
        final extension = _getExtensionFromFileType(assignment.fileType);
        fileName = '${assignment.id}$extension';
      }

      final filePath = '${downloadsDir.path}/$fileName';
      final file = File(filePath);

      if (await file.exists()) {
        await file.delete();
      }

      final response = await http.Client().send(http.Request('GET', uri));
      final contentLength = response.contentLength ?? 0;

      final sink = file.openWrite();
      int bytesReceived = 0;

      await response.stream.listen((List<int> chunk) {
        sink.add(chunk);
        bytesReceived += chunk.length;

        if (contentLength > 0) {
          setState(() {
            _assignmentDownloadProgress[assignment.id] =
                bytesReceived / contentLength;
          });
        }
      }).asFuture();

      await sink.flush();
      await sink.close();

      setState(() {
        _downloadedAssignments[assignment.id] = filePath;
        _assignmentDownloadProgress.remove(assignment.id);
      });

      await _saveDownloadedAssignments();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${assignment.title} downloaded successfully'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _assignmentDownloadProgress.remove(assignment.id);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to download ${assignment.title}: ${e.toString()}',
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
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
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              const Spacer(),
              if (_lastCacheUpdate != null && !_shouldRefreshData())
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.cached, size: 14, color: Colors.green),
                      const SizedBox(width: 4),
                      Text(
                        'Cached',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.green,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(width: 8),
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
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert),
                  tooltip: 'Refresh Options',
                  onSelected: (value) {
                    switch (value) {
                      case 'smart':
                        _smartRefresh();
                        break;
                      case 'force':
                        _forceRefresh();
                        break;
                      case 'clear':
                        _clearCacheAndRefresh();
                        break;
                    }
                  },
                  itemBuilder:
                      (context) => [
                        const PopupMenuItem(
                          value: 'smart',
                          child: Row(
                            children: [
                              Icon(Icons.refresh, size: 20),
                              SizedBox(width: 8),
                              Text('Smart Refresh'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'force',
                          child: Row(
                            children: [
                              Icon(Icons.refresh_outlined, size: 20),
                              SizedBox(width: 8),
                              Text('Force Refresh'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'clear',
                          child: Row(
                            children: [
                              Icon(Icons.clear_all, size: 20),
                              SizedBox(width: 8),
                              Text('Clear Cache'),
                            ],
                          ),
                        ),
                      ],
                ),
            ],
          ),

          const SizedBox(height: 16),

          // View selector
          Container(
            decoration: BoxDecoration(
              color: isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
              borderRadius: BorderRadius.circular(8),
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
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
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
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
            const SizedBox(height: 16),
            Text(
              'Error Loading Resources',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: TextStyle(
                color:
                    isDark
                        ? AppTheme.darkTextSecondary
                        : AppTheme.lightTextSecondary,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                _clearError();
                _refreshAll();
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    isLecturer
                        ? (isDark
                            ? AppTheme.darkSecondaryStart
                            : AppTheme.lightSecondaryStart)
                        : (isDark
                            ? AppTheme.darkPrimaryStart
                            : AppTheme.lightPrimaryStart),
                foregroundColor: Colors.white,
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
    return SingleChildScrollView(
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

    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: _classes.length,
      itemBuilder: (context, index) {
        final classModel = _classes[index];
        final resources = _resourcesByClass[classModel.id] ?? [];

        return _buildClassResourcesSection(
          context,
          classModel,
          resources,
          isLecturer,
          isDark,
        );
      },
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

    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: _classes.length,
      itemBuilder: (context, index) {
        final classModel = _classes[index];
        final assignments = _assignmentsByClass[classModel.id] ?? [];

        return _buildClassAssignmentsSection(
          context,
          classModel,
          assignments,
          isLecturer,
          isDark,
        );
      },
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
          Icons.class_,
          isLecturer,
          isDark,
        ),
        _buildStatCard(
          'Resources',
          '${_resources.length}',
          Icons.folder,
          isLecturer,
          isDark,
        ),
        _buildStatCard(
          'Assignments',
          '${_assignments.length}',
          Icons.assignment,
          isLecturer,
          isDark,
        ),
        _buildStatCard(
          'Recent Items',
          '${(_resources.take(5).length + _assignments.take(5).length)}',
          Icons.schedule,
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
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: (isDark ? Colors.grey[800] : Colors.grey[200])!,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient:
                  isLecturer
                      ? AppTheme.secondaryGradient(isDark)
                      : AppTheme.primaryGradient(isDark),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
          const Spacer(),
          Text(
            count,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          Text(
            title,
            style: TextStyle(
              color:
                  isDark
                      ? AppTheme.darkTextSecondary
                      : AppTheme.lightTextSecondary,
              fontSize: 12,
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
    return GradientContainer(
      useSecondaryGradient: isLecturer,
      padding: const EdgeInsets.all(24),
      borderRadius: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(
            Icons.folder_open,
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
          const SizedBox(height: 16),
          const Text(
            'No Resources Yet',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            isLecturer
                ? 'Upload resources for your classes to get started'
                : 'Your course resources will appear here',
            style: TextStyle(
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
            Icon(
              Icons.school_outlined,
              size: 64,
              color: isDark ? Colors.grey[600] : Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              isLecturer ? 'No Classes Created' : 'No Classes Joined',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              isLecturer
                  ? 'Create your first class to start sharing resources'
                  : 'Join a class to access resources and assignments',
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

  Widget _buildClassResourcesSection(
    BuildContext context,
    ClassModel classModel,
    List<ResourceModel> resources,
    bool isLecturer,
    bool isDark,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Class header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient:
                  isLecturer
                      ? AppTheme.secondaryGradient(isDark)
                      : AppTheme.primaryGradient(isDark),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.class_, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        classModel.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        classModel.courseCode,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${resources.length} resources',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Resources list
          if (resources.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'No resources uploaded yet',
                style: TextStyle(
                  color:
                      isDark
                          ? AppTheme.darkTextSecondary
                          : AppTheme.lightTextSecondary,
                ),
                textAlign: TextAlign.center,
              ),
            )
          else
            ...resources.map(
              (resource) =>
                  _buildResourceCard(resource, classModel, isLecturer, isDark),
            ),
        ],
      ),
    );
  }

  Widget _buildClassAssignmentsSection(
    BuildContext context,
    ClassModel classModel,
    List<AssignmentModel> assignments,
    bool isLecturer,
    bool isDark,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Class header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient:
                  isLecturer
                      ? AppTheme.secondaryGradient(isDark)
                      : AppTheme.primaryGradient(isDark),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.assignment, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        classModel.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        classModel.courseCode,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${assignments.length} assignments',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Assignments list
          if (assignments.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'No assignments created yet',
                style: TextStyle(
                  color:
                      isDark
                          ? AppTheme.darkTextSecondary
                          : AppTheme.lightTextSecondary,
                ),
                textAlign: TextAlign.center,
              ),
            )
          else
            ...assignments.map(
              (assignment) => _buildAssignmentCard(
                assignment,
                classModel,
                isLecturer,
                isDark,
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
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isDownloaded ? () => _openFile(resource) : null,
          onLongPress:
              isLecturer ? () => _showResourceDeleteOptions(resource) : null,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: (isDark ? Colors.grey[800] : Colors.grey[200])!,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _getFileColor(resource.fileType).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
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
                        style: TextStyle(
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
                        style: TextStyle(
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
                    icon: const Icon(Icons.open_in_new, size: 20),
                    onPressed: () => _openFile(resource),
                    tooltip: 'Open',
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
                    icon: const Icon(Icons.download, size: 20),
                    onPressed: () => _downloadFile(resource),
                    tooltip: 'Download',
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
      margin: const EdgeInsets.only(bottom: 12),
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
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: (isDark ? Colors.grey[800] : Colors.grey[200])!,
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
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    hasFile
                        ? _getFileIconData(assignment.fileType)
                        : Icons.assignment,
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
                        style: TextStyle(
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
                        style: TextStyle(
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
                      icon: const Icon(Icons.open_in_new, size: 20),
                      onPressed: () => _openAssignmentFile(assignment),
                      tooltip: 'Open',
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
                      icon: const Icon(Icons.download, size: 20),
                      onPressed: () => _downloadAssignmentFile(assignment),
                      tooltip: 'Download',
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
}
