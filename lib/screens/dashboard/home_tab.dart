import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/auth_provider.dart';
import '../../providers/class_provider.dart';
import '../../utils/app_theme.dart';
import '../../widgets/gradient_container.dart';
import '../../models/user_model.dart';
import '../class_details_screen.dart';

class HomeTab extends StatefulWidget {
  const HomeTab({Key? key}) : super(key: key);

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> with SingleTickerProviderStateMixin {
  bool _isLoading = false;
  bool _isRefreshing = false;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _scaleAnimation = Tween<double>(begin: 0.95, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutQuint),
    );

    _animationController.forward();

    // Use Future.microtask to avoid setState during build
    Future.microtask(() {
      _loadData();
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    if (!mounted) return;

    // Only show loading indicator if we have no data
    final classProvider = Provider.of<ClassProvider>(context, listen: false);

    setState(() {
      if (classProvider.classes.isEmpty) {
        _isLoading = true;
      }
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      // Load classes - this will first try to load from cache
      if (authProvider.isLecturer) {
        await classProvider.loadLecturerClasses();
      } else if (authProvider.isStudent) {
        await classProvider.loadStudentClasses();
      }

      // If we already have cached data, refresh in the background
      if (classProvider.classes.isNotEmpty) {
        // Don't show loading, just refresh in background
        await classProvider.refreshClasses(
          isLecturer: authProvider.isLecturer,
          showLoadingIndicator: false,
        );
      }
    } catch (e) {
      // Handle error - but don't show if we loaded cached data
      final classProvider = Provider.of<ClassProvider>(context, listen: false);

      if (classProvider.classes.isEmpty && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('You\'re offline. Please connect to the internet.'),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 3),
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
  Future<void> _refreshData() async {
    setState(() {
      _isRefreshing = true;
    });

    try {
      final classProvider = Provider.of<ClassProvider>(context, listen: false);
      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      await classProvider.refreshClasses(isLecturer: authProvider.isLecturer);
    } catch (e) {
      // Handle error
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error refreshing data: ${e.toString()}'),
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

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final classProvider = Provider.of<ClassProvider>(context);
    final classes = classProvider.classes;
    final isLecturer = authProvider.isLecturer;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final User? user = authProvider.currentUser;
    final now = DateTime.now();
    final isOffline = classProvider.isOffline;

    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Transform.scale(scale: _scaleAnimation.value, child: child);
      },
      child: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refreshData,
          child:
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Welcome message with gradient
                        Row(
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _getGreeting(),
                                  style: GoogleFonts.inter(
                                    fontSize: 16,
                                    color:
                                        isDark
                                            ? AppTheme.darkTextSecondary
                                            : AppTheme.lightTextSecondary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    ShaderMask(
                                      shaderCallback:
                                          (bounds) => (isLecturer
                                                  ? AppTheme.secondaryGradient(
                                                    isDark,
                                                  )
                                                  : AppTheme.primaryGradient(
                                                    isDark,
                                                  ))
                                              .createShader(bounds),
                                      child: Text(
                                        user?.fullName.split(' ').first ??
                                            'User',
                                        style: GoogleFonts.inter(
                                          fontSize: 24,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const Spacer(),
                            Stack(
                              children: [
                                CircleAvatar(
                                  radius: 26,
                                  backgroundColor:
                                      isLecturer
                                          ? (isDark
                                              ? AppTheme.darkSecondaryStart
                                                  .withOpacity(0.2)
                                              : AppTheme.lightSecondaryStart
                                                  .withOpacity(0.2))
                                          : (isDark
                                              ? AppTheme.darkPrimaryStart
                                                  .withOpacity(0.2)
                                              : AppTheme.lightPrimaryStart
                                                  .withOpacity(0.2)),
                                  child: Icon(
                                    Icons.person_outline_rounded,
                                    size: 30,
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
                                if (isOffline)
                                  Positioned(
                                    right: 0,
                                    bottom: 0,
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: Colors.red,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color:
                                              isDark
                                                  ? Colors.black
                                                  : Colors.white,
                                          width: 2,
                                        ),
                                      ),
                                      child: const Icon(
                                        Icons.wifi_off,
                                        size: 12,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),

                        const SizedBox(height: 24),

                        // Date display with gradient container
                        GradientContainer(
                          useSecondaryGradient: isLecturer,
                          padding: const EdgeInsets.all(16),
                          borderRadius: 28,
                          useCardStyle: false,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    DateFormat('EEEE').format(now),
                                    style: GoogleFonts.inter(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    DateFormat('MMMM d, yyyy').format(now),
                                    style: GoogleFonts.inter(
                                      fontSize: 14,
                                      color: Colors.white.withOpacity(0.85),
                                    ),
                                  ),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(28),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.calendar_today_outlined,
                                      size: 16,
                                      color: Colors.white,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Today',
                                      style: GoogleFonts.inter(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Offline indicator if offline
                        if (isOffline)
                          Container(
                            margin: const EdgeInsets.only(bottom: 24),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.orange.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(28),
                              border: Border.all(
                                color: Colors.orange,
                                width: 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.wifi_off,
                                  color: Colors.orange,
                                  size: 20,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'You are currently offline. Some features may be limited.',
                                    style: TextStyle(
                                      color: Colors.orange.shade800,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                        // Statistics section
                        _buildStatisticsSection(
                          context,
                          classes,
                          isLecturer,
                          isDark,
                        ),

                        const SizedBox(height: 24),

                        // Recent classes section
                        _buildRecentClassesSection(
                          context,
                          classes,
                          isLecturer,
                          isDark,
                        ),

                        // Refreshing indicator at bottom
                        if (_isRefreshing)
                          Container(
                            margin: const EdgeInsets.symmetric(vertical: 24),
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
                                    'Refreshing...',
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
                      ],
                    ),
                  ),
        ),
      ),
    );
  }

  Widget _buildStatisticsSection(
    BuildContext context,
    List classes,
    bool isLecturer,
    bool isDark,
  ) {
    // Get the ClassProvider
    final classProvider = Provider.of<ClassProvider>(context);
    final isOffline = classProvider.isOffline;

    // Different statistics for lecturers and students
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Overview',
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color:
                isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                context: context,
                icon: isLecturer ? Icons.class_outlined : Icons.school_outlined,
                title: isLecturer ? 'My Classes' : 'My Courses',
                value: classes.length.toString(),
                gradient:
                    isLecturer
                        ? AppTheme.secondaryGradient(isDark)
                        : AppTheme.primaryGradient(isDark),
                isDark: isDark,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildStatCard(
                context: context,
                icon:
                    isLecturer
                        ? Icons.people_outline
                        : Icons.assignment_outlined,
                title: isLecturer ? 'Students' : 'Assignments',
                value:
                    isLecturer
                        ? (isOffline && classProvider.totalStudents == 0
                            ? '—'
                            : classProvider.totalStudents.toString())
                        : '0',
                gradient:
                    isLecturer
                        ? AppTheme.secondaryGradient(isDark)
                        : AppTheme.primaryGradient(isDark),
                isDark: isDark,
                showOfflineIndicator: isLecturer && isOffline,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String value,
    required LinearGradient gradient,
    required bool isDark,
    bool showOfflineIndicator = false,
  }) {
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
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: gradient,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Text(
                value,
                style: GoogleFonts.inter(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color:
                      isDark
                          ? AppTheme.darkTextPrimary
                          : AppTheme.lightTextPrimary,
                ),
              ),
              if (showOfflineIndicator)
                Padding(
                  padding: const EdgeInsets.only(left: 8.0),
                  child: Tooltip(
                    message: 'Using cached student count while offline',
                    child: Icon(
                      Icons.offline_bolt,
                      size: 16,
                      color: Colors.orange,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 14,
              color:
                  isDark
                      ? AppTheme.darkTextSecondary
                      : AppTheme.lightTextSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentClassesSection(
    BuildContext context,
    List classes,
    bool isLecturer,
    bool isDark,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Recent Classes',
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color:
                    isDark
                        ? AppTheme.darkTextPrimary
                        : AppTheme.lightTextPrimary,
              ),
            ),
            TextButton(
              onPressed: () {
                // Navigate to Classes tab (index 1)
                DefaultTabController.of(context)?.animateTo(1);
              },
              child: Text(
                'View All',
                style: GoogleFonts.inter(
                  color:
                      isLecturer
                          ? (isDark
                              ? AppTheme.darkSecondaryStart
                              : AppTheme.lightSecondaryStart)
                          : (isDark
                              ? AppTheme.darkPrimaryStart
                              : AppTheme.lightPrimaryStart),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        classes.isEmpty
            ? _buildEmptyClassesState(context, isLecturer, isDark)
            : ListView.builder(
              physics: const NeverScrollableScrollPhysics(),
              shrinkWrap: true,
              itemCount: classes.length > 3 ? 3 : classes.length,
              itemBuilder: (context, index) {
                final classItem = classes[index];
                return _buildClassItem(
                  context: context,
                  classItem: classItem,
                  isLecturer: isLecturer,
                  isDark: isDark,
                );
              },
            ),
      ],
    );
  }

  Widget _buildClassItem({
    required BuildContext context,
    required dynamic classItem,
    required bool isLecturer,
    required bool isDark,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
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
            Navigator.push(
              context,
              PageRouteBuilder(
                pageBuilder:
                    (context, animation, secondaryAnimation) =>
                        ClassDetailsScreen(classModel: classItem),
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
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    gradient:
                        isLecturer
                            ? AppTheme.secondaryGradient(isDark)
                            : AppTheme.primaryGradient(isDark),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.class_outlined,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        classItem.name,
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
                      Text(
                        classItem.courseCode,
                        style: GoogleFonts.inter(
                          color:
                              isDark
                                  ? AppTheme.darkTextSecondary
                                  : AppTheme.lightTextSecondary,
                        ),
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

  Widget _buildEmptyClassesState(
    BuildContext context,
    bool isLecturer,
    bool isDark,
  ) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color:
                  isLecturer
                      ? (isDark
                          ? AppTheme.darkSecondaryStart.withOpacity(0.2)
                          : AppTheme.lightSecondaryStart.withOpacity(0.1))
                      : (isDark
                          ? AppTheme.darkPrimaryStart.withOpacity(0.2)
                          : AppTheme.lightPrimaryStart.withOpacity(0.1)),
              shape: BoxShape.circle,
              border: Border.all(
                color:
                    isLecturer
                        ? (isDark
                            ? AppTheme.darkSecondaryStart.withOpacity(0.5)
                            : AppTheme.lightSecondaryStart.withOpacity(0.5))
                        : (isDark
                            ? AppTheme.darkPrimaryStart.withOpacity(0.5)
                            : AppTheme.lightPrimaryStart.withOpacity(0.5)),
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
          const SizedBox(height: 16),
          Text(
            isLecturer ? 'No classes created yet' : 'No classes joined yet',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color:
                  isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isLecturer
                ? 'Create your first class to get started'
                : 'Join a class to get started',
            style: GoogleFonts.inter(
              color:
                  isDark
                      ? AppTheme.darkTextSecondary
                      : AppTheme.lightTextSecondary,
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return 'Good Morning,';
    } else if (hour < 17) {
      return 'Good Afternoon,';
    } else {
      return 'Good Evening,';
    }
  }
}
