import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/auth_provider.dart';
import '../../providers/class_provider.dart';
import '../../utils/app_theme.dart';
import '../../widgets/gradient_button.dart';
import '../../models/class_model.dart';
import '../class_details_screen.dart';
import '../lecturer/create_class_screen.dart';
import '../lecturer/edit_class_screen.dart';
import '../student/join_class_screen.dart';

class ClassesTab extends StatefulWidget {
  const ClassesTab({Key? key}) : super(key: key);

  @override
  State<ClassesTab> createState() => _ClassesTabState();
}

class _ClassesTabState extends State<ClassesTab> {
  bool _isLoading = false;
  bool _isRefreshing = false;
  bool _isGridView =
      false; // Changed from true to false to make list view default

  @override
  void initState() {
    super.initState();
    // Use Future.microtask to avoid setState during build
    Future.microtask(() {
      _loadClasses();
    });
  }

  Future<void> _loadClasses() async {
    if (!mounted) return;

    // Only show loading indicator if we have no cached data
    final classProvider = Provider.of<ClassProvider>(context, listen: false);

    setState(() {
      if (classProvider.classes.isEmpty) {
        _isLoading = true;
      }
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      if (authProvider.isLecturer) {
        await classProvider.loadLecturerClasses();
      } else if (authProvider.isStudent) {
        await classProvider.loadStudentClasses();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load classes: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Refresh data - force refresh from server
  Future<void> _refreshClasses() async {
    setState(() {
      _isRefreshing = true;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final classProvider = Provider.of<ClassProvider>(context, listen: false);

      await classProvider.refreshClasses(isLecturer: authProvider.isLecturer);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to refresh classes: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isRefreshing = false;
        });
      }
    }
  }

  // Create or join a class
  Future<void> _createOrJoinClass(BuildContext context, bool isLecturer) async {
    // Check if offline
    final classProvider = Provider.of<ClassProvider>(context, listen: false);
    if (classProvider.isOffline) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isLecturer
                ? 'Cannot create class while offline'
                : 'Cannot join class while offline',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final result = await Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder:
            (context, animation, secondaryAnimation) =>
                isLecturer
                    ? const CreateClassScreen()
                    : const JoinClassScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(0.0, 1.0);
          const end = Offset.zero;
          const curve = Curves.easeOutQuint;

          var tween = Tween(
            begin: begin,
            end: end,
          ).chain(CurveTween(curve: curve));
          var offsetAnimation = animation.drive(tween);

          return SlideTransition(position: offsetAnimation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );

    // Only reload if a class was created or joined
    if (result == true) {
      _loadClasses();
    }
  }

  // Show options when long pressing a class card
  void _showClassOptions(
    BuildContext context,
    ClassModel classModel,
    bool isLecturer,
    bool isDark,
  ) {
    // Check if offline for operation that requires network
    final classProvider = Provider.of<ClassProvider>(context, listen: false);
    final isOffline = classProvider.isOffline;

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder:
          (context) => Padding(
            padding: const EdgeInsets.symmetric(
              vertical: 24.0,
              horizontal: 16.0,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 24),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    color:
                        isDark
                            ? AppTheme.darkTextSecondary.withOpacity(0.5)
                            : AppTheme.lightTextSecondary.withOpacity(0.5),
                  ),
                ),
                Text(
                  classModel.name,
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color:
                        isDark
                            ? AppTheme.darkTextPrimary
                            : AppTheme.lightTextPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  classModel.courseCode,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color:
                        isDark
                            ? AppTheme.darkTextSecondary
                            : AppTheme.lightTextSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
                if (isOffline)
                  Container(
                    margin: const EdgeInsets.only(top: 12),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(color: Colors.orange, width: 1),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.wifi_off, color: Colors.orange, size: 16),
                        const SizedBox(width: 8),
                        Text(
                          'Offline mode',
                          style: TextStyle(
                            color: Colors.orange.shade800,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 24),
                ListTile(
                  leading: Icon(
                    Icons.copy_outlined,
                    color:
                        isDark
                            ? AppTheme.darkTextPrimary
                            : AppTheme.lightTextPrimary,
                  ),
                  title: Text(
                    'Copy Class Code',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w500),
                  ),
                  onTap: () {
                    Clipboard.setData(
                      ClipboardData(text: classModel.code),
                    ).then((_) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Class code copied to clipboard'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    });
                  },
                ),
                if (isLecturer) ...[
                  ListTile(
                    leading: Icon(
                      Icons.edit_outlined,
                      color:
                          isOffline
                              ? Colors.grey
                              : (isDark
                                  ? AppTheme.darkTextPrimary
                                  : AppTheme.lightTextPrimary),
                    ),
                    title: Text(
                      'Edit Class',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w500,
                        color: isOffline ? Colors.grey : null,
                      ),
                    ),
                    onTap:
                        isOffline
                            ? () {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Cannot edit class while offline',
                                  ),
                                  backgroundColor: Colors.orange,
                                ),
                              );
                            }
                            : () async {
                              Navigator.pop(context);
                              final result = await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder:
                                      (context) => EditClassScreen(
                                        classModel: classModel,
                                      ),
                                ),
                              );

                              // Reload classes if the class was updated
                              if (result == true) {
                                _loadClasses();
                              }
                            },
                  ),
                  ListTile(
                    leading: Icon(
                      Icons.delete_outline,
                      color: isOffline ? Colors.grey : Colors.red,
                    ),
                    title: Text(
                      'Delete Class',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w500,
                        color: isOffline ? Colors.grey : Colors.red,
                      ),
                    ),
                    onTap:
                        isOffline
                            ? () {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Cannot delete class while offline',
                                  ),
                                  backgroundColor: Colors.orange,
                                ),
                              );
                            }
                            : () {
                              Navigator.pop(context);
                              _showDeleteConfirmation(
                                context,
                                classModel,
                                isDark,
                              );
                            },
                  ),
                ],
              ],
            ),
          ),
    );
  }

  // Delete confirmation dialog
  Future<void> _showDeleteConfirmation(
    BuildContext context,
    ClassModel classModel,
    bool isDark,
  ) async {
    return showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor:
                isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
            title: Text(
              'Delete Class',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.bold,
                color:
                    isDark
                        ? AppTheme.darkTextPrimary
                        : AppTheme.lightTextPrimary,
              ),
            ),
            content: Text(
              'Are you sure you want to delete "${classModel.name}"? This action cannot be undone.',
              style: GoogleFonts.inter(
                color:
                    isDark
                        ? AppTheme.darkTextPrimary
                        : AppTheme.lightTextPrimary,
              ),
            ),
            actions: [
              TextButton(
                child: Text(
                  'Cancel',
                  style: GoogleFonts.inter(
                    color:
                        isDark
                            ? AppTheme.darkTextSecondary
                            : AppTheme.lightTextSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                onPressed: () => Navigator.pop(context),
              ),
              TextButton(
                child: Text(
                  'Delete',
                  style: GoogleFonts.inter(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onPressed: () async {
                  Navigator.pop(context);

                  // Remove the loading dialog approach and handle directly
                  try {
                    final classProvider = Provider.of<ClassProvider>(
                      context,
                      listen: false,
                    );
                    await classProvider.deleteClass(classModel.id);

                    if (context.mounted) {
                      // Show success message
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Class deleted successfully'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      // Show error message
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Failed to delete class: ${e.toString()}',
                          ),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                },
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final classProvider = Provider.of<ClassProvider>(context);
    final classes = classProvider.classes;
    final isLecturer = authProvider.isLecturer;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isOffline = classProvider.isOffline;

    return Scaffold(
      floatingActionButton: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors:
                isLecturer
                    ? (isDark
                        ? [
                          AppTheme.darkSecondaryStart,
                          AppTheme.darkSecondaryEnd,
                        ]
                        : [
                          AppTheme.lightSecondaryStart,
                          AppTheme.lightSecondaryEnd,
                        ])
                    : (isDark
                        ? [AppTheme.darkPrimaryStart, AppTheme.darkPrimaryEnd]
                        : [
                          AppTheme.lightPrimaryStart,
                          AppTheme.lightPrimaryEnd,
                        ]),
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color:
                isLecturer
                    ? (isDark ? AppTheme.darkBorder : AppTheme.lightBorder)
                    : (isDark ? AppTheme.darkBorder : AppTheme.lightBorder),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color:
                  isLecturer
                      ? (isDark
                              ? AppTheme.darkSecondaryStart
                              : AppTheme.lightSecondaryStart)
                          .withOpacity(0.25)
                      : (isDark
                              ? AppTheme.darkPrimaryStart
                              : AppTheme.lightPrimaryStart)
                          .withOpacity(0.25),
              blurRadius: 10,
              offset: const Offset(0, 4),
              spreadRadius: 0.5,
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(28),
            onTap: () => _createOrJoinClass(context, isLecturer),
            splashColor: Colors.white.withOpacity(0.1),
            highlightColor: Colors.white.withOpacity(0.05),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isLecturer ? Icons.add_rounded : Icons.login_outlined,
                    color: Colors.white,
                    size: 22,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isLecturer ? 'Create Class' : 'Join Class',
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refreshClasses,
          child: CustomScrollView(
            slivers: [
              // Header with title and view toggle
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                sliver: SliverToBoxAdapter(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ShaderMask(
                            shaderCallback:
                                (bounds) => (isLecturer
                                        ? AppTheme.secondaryGradient(isDark)
                                        : AppTheme.primaryGradient(isDark))
                                    .createShader(bounds),
                            child: Text(
                              isLecturer ? 'My Classes' : 'My Courses',
                              style: GoogleFonts.inter(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          if (isOffline)
                            Container(
                              margin: const EdgeInsets.only(top: 4),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.orange.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.orange,
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.wifi_off,
                                    color: Colors.orange,
                                    size: 12,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Offline mode',
                                    style: TextStyle(
                                      color: Colors.orange.shade800,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                      // View toggle button
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color:
                              isDark ? AppTheme.darkBorder : Colors.grey[200],
                          borderRadius: BorderRadius.circular(28),
                        ),
                        child: Row(
                          children: [
                            _buildViewToggleButton(
                              icon: Icons.grid_view_outlined,
                              isSelected: _isGridView,
                              onTap: () => setState(() => _isGridView = true),
                              isDark: isDark,
                              isLecturer: isLecturer,
                            ),
                            _buildViewToggleButton(
                              icon: Icons.view_list_outlined,
                              isSelected: !_isGridView,
                              onTap: () => setState(() => _isGridView = false),
                              isDark: isDark,
                              isLecturer: isLecturer,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Classes grid/list or empty state
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver:
                    _isLoading
                        ? const SliverFillRemaining(
                          child: Center(child: CircularProgressIndicator()),
                        )
                        : classes.isEmpty
                        ? SliverFillRemaining(
                          child: _buildEmptyState(context, isLecturer, isDark),
                        )
                        : _isGridView
                        ? SliverGrid(
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                childAspectRatio: 0.85,
                                crossAxisSpacing: 16,
                                mainAxisSpacing: 16,
                              ),
                          delegate: SliverChildBuilderDelegate(
                            (context, index) => _buildClassCard(
                              context,
                              classes[index],
                              isLecturer,
                              isDark,
                            ),
                            childCount: classes.length,
                          ),
                        )
                        : SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) => Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: _buildClassListItem(
                                context,
                                classes[index],
                                isLecturer,
                                isDark,
                              ),
                            ),
                            childCount: classes.length,
                          ),
                        ),
              ),

              // Refreshing indicator
              if (_isRefreshing)
                SliverToBoxAdapter(
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 24),
                    child: Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 16,
                            height: 16,
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
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Refreshing classes...',
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
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildViewToggleButton({
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
    required bool isDark,
    required bool isLecturer,
  }) {
    final primaryColor =
        isLecturer
            ? (isDark
                ? AppTheme.darkSecondaryStart
                : AppTheme.lightSecondaryStart)
            : (isDark ? AppTheme.darkPrimaryStart : AppTheme.lightPrimaryStart);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color:
              isSelected ? primaryColor.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(24),
          border: isSelected ? Border.all(color: primaryColor, width: 1) : null,
        ),
        child: Icon(
          icon,
          size: 20,
          color:
              isSelected
                  ? primaryColor
                  : isDark
                  ? AppTheme.darkTextSecondary
                  : AppTheme.lightTextSecondary,
        ),
      ),
    );
  }

  Widget _buildClassCard(
    BuildContext context,
    ClassModel classModel,
    bool isLecturer,
    bool isDark,
  ) {
    final primaryColor =
        isLecturer
            ? (isDark
                ? AppTheme.darkSecondaryStart
                : AppTheme.lightSecondaryStart)
            : (isDark ? AppTheme.darkPrimaryStart : AppTheme.lightPrimaryStart);

    final gradientColors =
        isLecturer
            ? [AppTheme.lightSecondaryStart, AppTheme.lightSecondaryEnd]
            : [AppTheme.lightPrimaryStart, AppTheme.lightPrimaryEnd];

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(28),
        child: InkWell(
          borderRadius: BorderRadius.circular(28),
          onTap: () {
            // Navigate to class details
            Navigator.push(
              context,
              PageRouteBuilder(
                pageBuilder:
                    (context, animation, secondaryAnimation) =>
                        ClassDetailsScreen(classModel: classModel),
                transitionsBuilder: (
                  context,
                  animation,
                  secondaryAnimation,
                  child,
                ) {
                  const begin = Offset(1.0, 0.0);
                  const end = Offset.zero;
                  const curve = Curves.easeOutQuint;

                  var tween = Tween(
                    begin: begin,
                    end: end,
                  ).chain(CurveTween(curve: curve));
                  var offsetAnimation = animation.drive(tween);

                  return SlideTransition(
                    position: offsetAnimation,
                    child: child,
                  );
                },
              ),
            );
          },
          onLongPress:
              () => _showClassOptions(context, classModel, isLecturer, isDark),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Content
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Class icon with gradient background
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: gradientColors,
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(
                          isLecturer
                              ? Icons.school_outlined
                              : Icons.class_outlined,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Class name
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
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),

                      const SizedBox(height: 8),

                      // Course code
                      Text(
                        classModel.courseCode,
                        style: GoogleFonts.inter(
                          color: primaryColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),

                      const Spacer(),

                      // Level info
                      Row(
                        children: [
                          Icon(
                            Icons.people_outline,
                            size: 14,
                            color:
                                isDark
                                    ? AppTheme.darkTextSecondary
                                    : AppTheme.lightTextSecondary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            classModel.level,
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
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildClassListItem(
    BuildContext context,
    ClassModel classModel,
    bool isLecturer,
    bool isDark,
  ) {
    final primaryColor =
        isLecturer
            ? (isDark
                ? AppTheme.darkSecondaryStart
                : AppTheme.lightSecondaryStart)
            : (isDark ? AppTheme.darkPrimaryStart : AppTheme.lightPrimaryStart);

    final gradientColors =
        isLecturer
            ? [AppTheme.lightSecondaryStart, AppTheme.lightSecondaryEnd]
            : [AppTheme.lightPrimaryStart, AppTheme.lightPrimaryEnd];

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(28),
        child: InkWell(
          borderRadius: BorderRadius.circular(28),
          onTap: () {
            // Navigate to class details
            Navigator.push(
              context,
              PageRouteBuilder(
                pageBuilder:
                    (context, animation, secondaryAnimation) =>
                        ClassDetailsScreen(classModel: classModel),
                transitionsBuilder: (
                  context,
                  animation,
                  secondaryAnimation,
                  child,
                ) {
                  const begin = Offset(1.0, 0.0);
                  const end = Offset.zero;
                  const curve = Curves.easeOutQuint;

                  var tween = Tween(
                    begin: begin,
                    end: end,
                  ).chain(CurveTween(curve: curve));
                  var offsetAnimation = animation.drive(tween);

                  return SlideTransition(
                    position: offsetAnimation,
                    child: child,
                  );
                },
              ),
            );
          },
          onLongPress:
              () => _showClassOptions(context, classModel, isLecturer, isDark),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Class icon with gradient background
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: gradientColors,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(
                    isLecturer ? Icons.school_outlined : Icons.class_outlined,
                    color: Colors.white,
                    size: 24,
                  ),
                ),

                const SizedBox(width: 16),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Class name
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
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),

                      const SizedBox(height: 4),

                      // Course code
                      Text(
                        classModel.courseCode,
                        style: GoogleFonts.inter(
                          color: primaryColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),

                      const SizedBox(height: 8),

                      // Level info
                      Row(
                        children: [
                          Icon(
                            Icons.people_outline,
                            size: 14,
                            color:
                                isDark
                                    ? AppTheme.darkTextSecondary
                                    : AppTheme.lightTextSecondary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            classModel.level,
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
                    ],
                  ),
                ),

                Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color:
                      isDark
                          ? AppTheme.darkTextSecondary
                          : AppTheme.lightTextSecondary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, bool isLecturer, bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
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
              size: 40,
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
            isLecturer ? 'No classes created yet' : 'No classes joined yet',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color:
                  isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              isLecturer
                  ? 'Create your first class to get started'
                  : 'Join a class to get started with your courses',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                color:
                    isDark
                        ? AppTheme.darkTextSecondary
                        : AppTheme.lightTextSecondary,
              ),
            ),
          ),
          const SizedBox(height: 32),
          GradientButton(
            text: isLecturer ? 'Create Class' : 'Join Class',
            onPressed: () => _createOrJoinClass(context, isLecturer),
            width: 200,
            useSecondaryGradient: isLecturer,
          ),
        ],
      ),
    );
  }
}
