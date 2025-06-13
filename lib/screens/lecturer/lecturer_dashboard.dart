import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/class_provider.dart';
import '../../providers/student_management_provider.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/class_card.dart';
import '../../models/user_model.dart';
import '../../screens/class_details_screen.dart';
import '../../utils/app_theme.dart';
import '../../services/supabase_service.dart';
import 'create_class_screen.dart';
import 'students_tab.dart';

class LecturerDashboard extends StatefulWidget {
  const LecturerDashboard({Key? key}) : super(key: key);

  @override
  State<LecturerDashboard> createState() => _LecturerDashboardState();
}

class _LecturerDashboardState extends State<LecturerDashboard>
    with SingleTickerProviderStateMixin {
  bool _isLoading = false;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    // Load classes when the dashboard is opened
    _loadClasses();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadClasses() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await Provider.of<ClassProvider>(
        context,
        listen: false,
      ).loadLecturerClasses();
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
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final classProvider = Provider.of<ClassProvider>(context);
    final lecturer = authProvider.currentUser as Lecturer?;
    final classes = classProvider.classes;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Lecturer Dashboard'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              // Get the ClassProvider to reset it
              final classProvider = Provider.of<ClassProvider>(
                context,
                listen: false,
              );
              await authProvider.signOut(
                resetClassProvider: () => classProvider.reset(),
              );

              if (context.mounted &&
                  authProvider.status == AuthStatus.unauthenticated) {
                // Navigate to login screen and clear the navigation stack
                Navigator.of(
                  context,
                ).pushNamedAndRemoveUntil('/login', (route) => false);
              }
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor:
              isDark ? Colors.white : Theme.of(context).primaryColor,
          labelColor: isDark ? Colors.white : Theme.of(context).primaryColor,
          unselectedLabelColor: isDark ? Colors.white70 : Colors.black54,
          tabs: const [
            Tab(icon: Icon(Icons.class_), text: 'Classes'),
            Tab(icon: Icon(Icons.people), text: 'Students'),
          ],
        ),
      ),
      floatingActionButton:
          _tabController.index == 0
              ? FloatingActionButton(
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const CreateClassScreen(),
                    ),
                  );
                  // Refresh classes after returning from create screen
                  _loadClasses();
                },
                child: const Icon(Icons.add),
                tooltip: 'Create a Class',
              )
              : null,
      body: ChangeNotifierProvider(
        create:
            (context) => StudentManagementProvider(
              Provider.of<AuthProvider>(context, listen: false).supabaseService,
            ),
        child: TabBarView(
          controller: _tabController,
          children: [
            // Classes tab
            RefreshIndicator(
              onRefresh: _loadClasses,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Welcome card
                    Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Welcome, ${lecturer?.fullName}',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 8),
                            Text('Staff ID: ${lecturer?.staffId ?? 'N/A'}'),
                            Text(
                              'Department: ${lecturer?.department ?? 'N/A'}',
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // My Classes section
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'My Classes',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        TextButton.icon(
                          onPressed: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const CreateClassScreen(),
                              ),
                            );
                            // Refresh classes after returning from create screen
                            _loadClasses();
                          },
                          icon: const Icon(Icons.add),
                          label: const Text('Create'),
                          style: TextButton.styleFrom(
                            foregroundColor: Theme.of(context).primaryColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Classes list or empty state
                    Expanded(
                      child:
                          _isLoading
                              ? const Center(child: CircularProgressIndicator())
                              : classes.isEmpty
                              ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(
                                      Icons.school_outlined,
                                      size: 64,
                                      color: Colors.grey,
                                    ),
                                    const SizedBox(height: 16),
                                    const Text(
                                      'No classes created yet',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.grey,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    const Text(
                                      'Create your first class by tapping the + button',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(color: Colors.grey),
                                    ),
                                    const SizedBox(height: 24),
                                    ElevatedButton.icon(
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder:
                                                (context) =>
                                                    const CreateClassScreen(),
                                          ),
                                        );
                                      },
                                      icon: const Icon(Icons.add),
                                      label: const Text('Create Class'),
                                    ),
                                  ],
                                ),
                              )
                              : ListView.builder(
                                itemCount: classes.length,
                                itemBuilder: (context, index) {
                                  return ClassCard(
                                    classModel: classes[index],
                                    showCode:
                                        true, // Show the class code for lecturers
                                    onTap: () {
                                      // Navigate to class details screen
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder:
                                              (context) => ClassDetailsScreen(
                                                classModel: classes[index],
                                              ),
                                        ),
                                      );
                                    },
                                  );
                                },
                              ),
                    ),
                  ],
                ),
              ),
            ),

            // Students Management Tab
            const StudentsTab(),
          ],
        ),
      ),
    );
  }
}
