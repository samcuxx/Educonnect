import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../utils/app_theme.dart';
import '../../widgets/gradient_container.dart';

class ResourcesTab extends StatefulWidget {
  const ResourcesTab({Key? key}) : super(key: key);

  @override
  State<ResourcesTab> createState() => _ResourcesTabState();
}

class _ResourcesTabState extends State<ResourcesTab> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  
  final List<Map<String, dynamic>> _resourceCategories = [
    {
      'title': 'Course Materials',
      'icon': Icons.book,
      'count': 0,
      'description': 'Access all course materials'
    },
    {
      'title': 'Assignments',
      'icon': Icons.assignment,
      'count': 0,
      'description': 'View and submit assignments'
    },
    {
      'title': 'Lecture Notes',
      'icon': Icons.note,
      'count': 0,
      'description': 'Access lecture notes'
    },
    {
      'title': 'Shared Resources',
      'icon': Icons.share,
      'count': 0,
      'description': 'Materials shared by others'
    },
  ];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeIn,
      ),
    );
    
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final isLecturer = authProvider.isLecturer;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Page title with gradient text
              ShaderMask(
                shaderCallback: (bounds) => (isLecturer
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
              
              const SizedBox(height: 24),
              
              // Resource categories grid
              GridView.builder(
                physics: const NeverScrollableScrollPhysics(),
                shrinkWrap: true,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 0.9,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                ),
                itemCount: _resourceCategories.length,
                itemBuilder: (context, index) {
                  final category = _resourceCategories[index];
                  return _buildResourceCard(
                    context: context,
                    title: category['title'],
                    icon: category['icon'],
                    count: category['count'],
                    description: category['description'],
                    isLecturer: isLecturer,
                    isDark: isDark,
                    index: index,
                  );
                },
              ),
              
              const SizedBox(height: 24),
              
              // Recent resources list
              Text(
                'Recent Resources',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              
              const SizedBox(height: 16),
              
              // Resources list or empty state
              _buildEmptyResourcesList(context, isLecturer, isDark),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildResourceCard({
    required BuildContext context,
    required String title,
    required IconData icon,
    required int count,
    required String description,
    required bool isLecturer,
    required bool isDark,
    required int index,
  }) {
    // Delay each card's animation for a cascading effect
    Future.delayed(Duration(milliseconds: 100 * index), () {
      if (mounted) {
        setState(() {});
      }
    });

    return AnimatedOpacity(
      opacity: 1.0,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOut,
      child: AnimatedScale(
        scale: 1.0,
        duration: const Duration(milliseconds: 500),
        curve: Curves.elasticOut,
        child: Container(
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
                // Handle resource category tap
              },
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: isLecturer
                            ? AppTheme.secondaryGradient(isDark)
                            : AppTheme.primaryGradient(isDark),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        icon,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark
                            ? AppTheme.darkTextSecondary
                            : AppTheme.lightTextSecondary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: (isLecturer
                                ? (isDark
                                    ? AppTheme.darkSecondaryStart
                                    : AppTheme.lightSecondaryStart)
                                : (isDark
                                    ? AppTheme.darkPrimaryStart
                                    : AppTheme.lightPrimaryStart))
                            .withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '$count items',
                        style: TextStyle(
                          fontSize: 12,
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
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyResourcesList(BuildContext context, bool isLecturer, bool isDark) {
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
            color: isLecturer
                ? (isDark ? AppTheme.darkSecondaryStart : AppTheme.lightSecondaryStart)
                : (isDark ? AppTheme.darkPrimaryStart : AppTheme.lightPrimaryStart),
          ),
          const SizedBox(height: 16),
          Text(
            'No Resources Yet',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            isLecturer
                ? 'Upload resources for your classes to get started'
                : 'Your course resources will appear here',
            style: TextStyle(
              color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          isLecturer
              ? ElevatedButton.icon(
                  onPressed: () {
                    // Handle upload
                  },
                  icon: const Icon(Icons.upload_file),
                  label: const Text('Upload Resources'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isLecturer
                        ? (isDark ? AppTheme.darkSecondaryStart : AppTheme.lightSecondaryStart)
                        : (isDark ? AppTheme.darkPrimaryStart : AppTheme.lightPrimaryStart),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                )
              : Container(),
        ],
      ),
    );
  }
} 