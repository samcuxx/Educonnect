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
import 'package:google_fonts/google_fonts.dart';

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

  // Track which classes are expanded
  Set<String> _expandedClasses = {};

  // Loading states
  bool _isLoading = false;
  bool _isInitialLoad = true;
  String? _error;

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

    // Load data immediately
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadAllData();
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
    setState(() {
      _isLoading = true;
      _error = null;
    });

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
        _isInitialLoad = false;
      });
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
    await _loadAllData();
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
            const SizedBox(height: 16),
            Text(
              'Error Loading Resources',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color:
                    isDark
                        ? AppTheme.darkTextPrimary
                        : AppTheme.lightTextPrimary,
              ),
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
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
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
}
