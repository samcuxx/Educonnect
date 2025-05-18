import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
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
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOutQuint,
      ),
    );
    
    _animationController.forward();
    _loadData();
  }
  
  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }
  
  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final classProvider = Provider.of<ClassProvider>(context, listen: false);
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      
      if (authProvider.isLecturer) {
        await classProvider.loadLecturerClasses();
      } else if (authProvider.isStudent) {
        await classProvider.loadStudentClasses();
      }
    } catch (e) {
      // Handle error
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
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
    
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: child,
        );
      },
      child: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadData,
          child: _isLoading
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
                                style: TextStyle(
                                  fontSize: 16,
                                  color: isDark 
                                      ? AppTheme.darkTextSecondary 
                                      : AppTheme.lightTextSecondary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  ShaderMask(
                                    shaderCallback: (bounds) => (isLecturer
                                            ? AppTheme.secondaryGradient(isDark)
                                            : AppTheme.primaryGradient(isDark))
                                        .createShader(bounds),
                                    child: Text(
                                      user?.fullName.split(' ').first ?? 'User',
                                      style: Theme.of(context)
                                          .textTheme
                                          .headlineSmall
                                          ?.copyWith(
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
                          CircleAvatar(
                            radius: 26,
                            backgroundColor: isLecturer
                                ? (isDark
                                    ? AppTheme.darkSecondaryStart.withOpacity(0.2)
                                    : AppTheme.lightSecondaryStart.withOpacity(0.2))
                                : (isDark
                                    ? AppTheme.darkPrimaryStart.withOpacity(0.2)
                                    : AppTheme.lightPrimaryStart.withOpacity(0.2)),
                            child: Icon(
                              Icons.person,
                              size: 30,
                              color: isLecturer
                                  ? (isDark
                                      ? AppTheme.darkSecondaryStart
                                      : AppTheme.lightSecondaryStart)
                                  : (isDark
                                      ? AppTheme.darkPrimaryStart
                                      : AppTheme.lightPrimaryStart),
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // Date display with gradient container
                      GradientContainer(
                        useSecondaryGradient: isLecturer,
                        padding: const EdgeInsets.all(16),
                        borderRadius: 16,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  DateFormat('EEEE').format(now),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  DateFormat('MMMM d, yyyy').format(now),
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: isDark
                                        ? AppTheme.darkTextSecondary
                                        : AppTheme.lightTextSecondary,
                                  ),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: isLecturer
                                    ? (isDark
                                        ? AppTheme.darkSecondaryStart.withOpacity(0.2)
                                        : AppTheme.lightSecondaryStart.withOpacity(0.2))
                                    : (isDark
                                        ? AppTheme.darkPrimaryStart.withOpacity(0.2)
                                        : AppTheme.lightPrimaryStart.withOpacity(0.2)),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.calendar_today,
                                    size: 16,
                                    color: isLecturer
                                        ? (isDark
                                            ? AppTheme.darkSecondaryStart
                                            : AppTheme.lightSecondaryStart)
                                        : (isDark
                                            ? AppTheme.darkPrimaryStart
                                            : AppTheme.lightPrimaryStart),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Today',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: isLecturer
                                          ? (isDark
                                              ? AppTheme.darkSecondaryStart
                                              : AppTheme.lightSecondaryStart)
                                          : (isDark
                                              ? AppTheme.darkPrimaryStart
                                              : AppTheme.lightPrimaryStart),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // Statistics section
                      _buildStatisticsSection(context, classes, isLecturer, isDark),
                      
                      const SizedBox(height: 24),
                      
                      // Recent classes section
                      _buildRecentClassesSection(context, classes, isLecturer, isDark),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
  
  Widget _buildStatisticsSection(
      BuildContext context, List classes, bool isLecturer, bool isDark) {
    // Different statistics for lecturers and students
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Overview',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                context: context,
                icon: isLecturer ? Icons.class_ : Icons.school,
                title: isLecturer ? 'My Classes' : 'My Courses',
                value: classes.length.toString(),
                gradient: isLecturer
                    ? AppTheme.secondaryGradient(isDark)
                    : AppTheme.primaryGradient(isDark),
                isDark: isDark,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildStatCard(
                context: context,
                icon: isLecturer ? Icons.people : Icons.assignment,
                title: isLecturer ? 'Students' : 'Assignments',
                value: '0', // This would come from a provider
                gradient: isLecturer
                    ? AppTheme.secondaryGradient(isDark)
                    : AppTheme.primaryGradient(isDark),
                isDark: isDark,
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
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: gradient,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            value,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildRecentClassesSection(
      BuildContext context, List classes, bool isLecturer, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Recent Classes',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            TextButton(
              onPressed: () {
                // Navigate to Classes tab
                // This would be handled by the parent widget
              },
              child: Text(
                'View All',
                style: TextStyle(
                  color: isLecturer
                      ? (isDark ? AppTheme.darkSecondaryStart : AppTheme.lightSecondaryStart)
                      : (isDark ? AppTheme.darkPrimaryStart : AppTheme.lightPrimaryStart),
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
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            Navigator.push(
              context,
              PageRouteBuilder(
                pageBuilder: (context, animation, secondaryAnimation) =>
                    ClassDetailsScreen(classModel: classItem),
                transitionsBuilder: (context, animation, secondaryAnimation, child) {
                  const begin = Offset(1.0, 0.0);
                  const end = Offset.zero;
                  const curve = Curves.easeOutQuint;
                  
                  var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
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
                    gradient: isLecturer
                        ? AppTheme.secondaryGradient(isDark)
                        : AppTheme.primaryGradient(isDark),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.class_,
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
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        classItem.courseCode,
                        style: TextStyle(
                          color: isDark
                              ? AppTheme.darkTextSecondary
                              : AppTheme.lightTextSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildEmptyClassesState(BuildContext context, bool isLecturer, bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isLecturer
                  ? (isDark
                      ? AppTheme.darkSecondaryStart.withOpacity(0.2)
                      : AppTheme.lightSecondaryStart.withOpacity(0.1))
                  : (isDark
                      ? AppTheme.darkPrimaryStart.withOpacity(0.2)
                      : AppTheme.lightPrimaryStart.withOpacity(0.1)),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isLecturer ? Icons.school_outlined : Icons.class_outlined,
              size: 40,
              color: isLecturer
                  ? (isDark ? AppTheme.darkSecondaryStart : AppTheme.lightSecondaryStart)
                  : (isDark ? AppTheme.darkPrimaryStart : AppTheme.lightPrimaryStart),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            isLecturer ? 'No classes created yet' : 'No classes joined yet',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isLecturer
                ? 'Create your first class to get started'
                : 'Join a class to get started',
            style: TextStyle(
              color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
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