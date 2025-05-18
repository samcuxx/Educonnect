import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/class_provider.dart';
import '../../utils/app_theme.dart';
import '../../widgets/gradient_button.dart';
import '../../models/class_model.dart';
import '../class_details_screen.dart';
import '../lecturer/create_class_screen.dart';
import '../student/join_class_screen.dart';

class ClassesTab extends StatefulWidget {
  const ClassesTab({Key? key}) : super(key: key);

  @override
  State<ClassesTab> createState() => _ClassesTabState();
}

class _ClassesTabState extends State<ClassesTab> with SingleTickerProviderStateMixin {
  bool _isLoading = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  
  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    
    _fadeAnimation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOut,
      ),
    );
    
    _animationController.forward();
    _loadClasses();
  }
  
  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }
  
  Future<void> _loadClasses() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final classProvider = Provider.of<ClassProvider>(context, listen: false);
      
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
  
  // Create or join a class
  Future<void> _createOrJoinClass(BuildContext context, bool isLecturer) async {
    final result = await Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => 
            isLecturer ? const CreateClassScreen() : const JoinClassScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(0.0, 1.0);
          const end = Offset.zero;
          const curve = Curves.easeOutQuint;
          
          var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
          var offsetAnimation = animation.drive(tween);
          
          return SlideTransition(
            position: offsetAnimation,
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );
    
    // Only reload if a class was created or joined
    if (result == true) {
      _loadClasses();
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final classProvider = Provider.of<ClassProvider>(context);
    final classes = classProvider.classes;
    final isLecturer = authProvider.isLecturer;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Scaffold(
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _createOrJoinClass(context, isLecturer),
          icon: Icon(isLecturer ? Icons.add : Icons.login),
          label: Text(isLecturer ? 'Create Class' : 'Join Class'),
          backgroundColor: isLecturer
              ? (isDark ? AppTheme.darkSecondaryStart : AppTheme.lightSecondaryStart)
              : (isDark ? AppTheme.darkPrimaryStart : AppTheme.lightPrimaryStart),
        ),
        body: SafeArea(
          child: RefreshIndicator(
            onRefresh: _loadClasses,
            child: CustomScrollView(
              slivers: [
                // Header with title
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: ShaderMask(
                      shaderCallback: (bounds) => (isLecturer
                              ? AppTheme.secondaryGradient(isDark)
                              : AppTheme.primaryGradient(isDark))
                          .createShader(bounds),
                      child: Text(
                        isLecturer ? 'My Classes' : 'My Courses',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                      ),
                    ),
                  ),
                ),
                
                // Classes grid or empty state
                SliverPadding(
                  padding: const EdgeInsets.all(16),
                  sliver: _isLoading
                      ? const SliverFillRemaining(
                          child: Center(child: CircularProgressIndicator()),
                        )
                      : classes.isEmpty
                          ? SliverFillRemaining(
                              child: _buildEmptyState(context, isLecturer, isDark),
                            )
                          : SliverGrid(
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                childAspectRatio: 0.8,
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
                            ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildClassCard(
      BuildContext context, ClassModel classModel, bool isLecturer, bool isDark) {
    return Container(
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
            // Navigate to class details
            Navigator.push(
              context,
              PageRouteBuilder(
                pageBuilder: (context, animation, secondaryAnimation) =>
                    ClassDetailsScreen(classModel: classModel),
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with gradient
              Container(
                height: 80,
                decoration: BoxDecoration(
                  gradient: isLecturer
                      ? AppTheme.secondaryGradient(isDark)
                      : AppTheme.primaryGradient(isDark),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                ),
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.class_,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const Spacer(),
                    if (isLecturer)
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
                          classModel.code,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              
              // Content
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        classModel.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        classModel.courseCode,
                        style: TextStyle(
                          color: isLecturer
                              ? (isDark ? AppTheme.darkSecondaryStart : AppTheme.lightSecondaryStart)
                              : (isDark ? AppTheme.darkPrimaryStart : AppTheme.lightPrimaryStart),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.people,
                                  size: 14,
                                  color: isDark
                                      ? AppTheme.darkTextSecondary
                                      : AppTheme.lightTextSecondary,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  classModel.level,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark
                                        ? AppTheme.darkTextSecondary
                                        : AppTheme.lightTextSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ],
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
              color: isLecturer
                  ? (isDark
                      ? AppTheme.darkSecondaryStart.withOpacity(0.1)
                      : AppTheme.lightSecondaryStart.withOpacity(0.1))
                  : (isDark
                      ? AppTheme.darkPrimaryStart.withOpacity(0.1)
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
          const SizedBox(height: 24),
          Text(
            isLecturer ? 'No classes created yet' : 'No classes joined yet',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
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
              style: TextStyle(
                color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
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