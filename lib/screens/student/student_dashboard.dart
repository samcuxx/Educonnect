import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/class_provider.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/class_card.dart';
import '../../models/user_model.dart';
import '../../screens/class_details_screen.dart';
import 'join_class_screen.dart';

class StudentDashboard extends StatefulWidget {
  const StudentDashboard({Key? key}) : super(key: key);

  @override
  State<StudentDashboard> createState() => _StudentDashboardState();
}

class _StudentDashboardState extends State<StudentDashboard> {
  bool _isLoading = false;
  
  @override
  void initState() {
    super.initState();
    // Load classes when the dashboard is opened
    _loadClasses();
  }
  
  Future<void> _loadClasses() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      await Provider.of<ClassProvider>(context, listen: false).loadStudentClasses();
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
    final student = authProvider.currentUser as Student?;
    final classes = classProvider.classes;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Student Dashboard'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              // Get the ClassProvider to reset it
              final classProvider = Provider.of<ClassProvider>(context, listen: false);
              authProvider.signOut(resetClassProvider: () => classProvider.reset());
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const JoinClassScreen()),
          );
          // Refresh classes after returning from join screen
          _loadClasses();
        },
        child: const Icon(Icons.add),
        tooltip: 'Join a Class',
      ),
      body: RefreshIndicator(
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
                        'Welcome, ${student?.fullName}',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Text('Student Number: ${student?.studentNumber ?? 'N/A'}'),
                      Text('Institution: ${student?.institution ?? 'N/A'}'),
                      Text('Level/Year: ${student?.level ?? 'N/A'}'),
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
                        MaterialPageRoute(builder: (context) => const JoinClassScreen()),
                      );
                      // Refresh classes after returning from join screen
                      _loadClasses();
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('Join'),
                    style: TextButton.styleFrom(
                      foregroundColor: Theme.of(context).primaryColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              
              // Classes list or empty state
              Expanded(
                child: _isLoading 
                  ? const Center(child: CircularProgressIndicator())
                  : classes.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.class_outlined,
                              size: 64,
                              color: Colors.grey,
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'No classes joined yet',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Join a class by entering a class code',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.grey),
                            ),
                            const SizedBox(height: 24),
                            ElevatedButton.icon(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => const JoinClassScreen()),
                                );
                              },
                              icon: const Icon(Icons.add),
                              label: const Text('Join Class'),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: classes.length,
                        itemBuilder: (context, index) {
                          return ClassCard(
                            classModel: classes[index],
                            showCode: false, // Don't show the class code for students
                            onTap: () {
                              // Navigate to class details screen
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ClassDetailsScreen(
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
} 