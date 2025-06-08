import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/class_provider.dart';
import '../widgets/class_card.dart';
import '../models/user_model.dart';
import 'class_details_screen.dart';
import 'lecturer/create_class_screen.dart';
import 'student/join_class_screen.dart';

class ClassDashboardScreen extends StatefulWidget {
  const ClassDashboardScreen({Key? key}) : super(key: key);

  @override
  State<ClassDashboardScreen> createState() => _ClassDashboardScreenState();
}

class _ClassDashboardScreenState extends State<ClassDashboardScreen> {
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Load classes only on first initialization
    _loadClasses();
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
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Method to create a class and refresh the list
  Future<void> _createClass(BuildContext context) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const CreateClassScreen()),
    );

    // Only reload if a class was actually created
    if (result == true) {
      _loadClasses();
    }
  }

  // Method to join a class and refresh the list
  Future<void> _joinClass(BuildContext context) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const JoinClassScreen()),
    );

    // Only reload if a class was actually joined
    if (result == true) {
      _loadClasses();
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final classProvider = Provider.of<ClassProvider>(context);
    final user = authProvider.currentUser;
    final classes = classProvider.classes;
    final isLecturer = authProvider.isLecturer;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const SizedBox(width: 4),
            Text('EduConnect', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          IconButton(
            icon: const CircleAvatar(
              radius: 14,
              child: Icon(Icons.person, size: 18),
            ),
            onPressed: () {
              // Show profile/settings menu
              showModalBottomSheet(
                context: context,
                builder:
                    (context) => _buildProfileSheet(
                      context,
                      user,
                      authProvider,
                      classProvider,
                    ),
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                ),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          if (isLecturer) {
            _createClass(context);
          } else {
            _joinClass(context);
          }
        },
        child: const Icon(Icons.add),
        tooltip: isLecturer ? 'Create Class' : 'Join Class',
      ),
      body: RefreshIndicator(
        onRefresh: _loadClasses,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Section title with action button
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isLecturer ? 'My Classes' : 'Joined Classes',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () {
                      if (isLecturer) {
                        _createClass(context);
                      } else {
                        _joinClass(context);
                      }
                    },
                    icon: Icon(isLecturer ? Icons.add : Icons.login),
                    label: Text(isLecturer ? 'Create' : 'Join'),
                    style: TextButton.styleFrom(
                      foregroundColor: Theme.of(context).primaryColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Classes list or empty state
              Expanded(
                child:
                    _isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : classes.isEmpty
                        ? _buildEmptyState(context, isLecturer)
                        : ListView.builder(
                          itemCount: classes.length,
                          itemBuilder: (context, index) {
                            return ClassCard(
                              classModel: classes[index],
                              showCode:
                                  isLecturer, // Only show code for lecturers
                              onTap: () {
                                // Navigate to class details screen without refreshing on return
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
    );
  }

  Widget _buildEmptyState(BuildContext context, bool isLecturer) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isLecturer ? Icons.school_outlined : Icons.class_outlined,
            size: 64,
            color: Colors.grey,
          ),
          const SizedBox(height: 16),
          Text(
            isLecturer ? 'No classes created yet' : 'No classes joined yet',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              isLecturer
                  ? 'Tap + to create your first class'
                  : 'Join a class by entering a class code',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              if (isLecturer) {
                _createClass(context);
              } else {
                _joinClass(context);
              }
            },
            icon: Icon(isLecturer ? Icons.add : Icons.login),
            label: Text(isLecturer ? 'Create Class' : 'Join Class'),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileSheet(
    BuildContext context,
    User? user,
    AuthProvider authProvider,
    ClassProvider classProvider,
  ) {
    final isLecturer = authProvider.isLecturer;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const CircleAvatar(
                radius: 30,
                child: Icon(Icons.person, size: 40),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user?.fullName ?? 'User',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      user?.email ?? '',
                      style: const TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isLecturer
                          ? (user as Lecturer?)?.department ?? ''
                          : (user as Student?)?.institution ?? '',
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Sign Out'),
            onTap: () async {
              Navigator.pop(context);
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
      ),
    );
  }
}
