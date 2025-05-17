import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/class_model.dart';
import '../models/user_model.dart';
import '../providers/auth_provider.dart';
import '../providers/class_provider.dart';
import '../services/supabase_service.dart';

class ClassDetailsScreen extends StatefulWidget {
  final ClassModel classModel;
  
  const ClassDetailsScreen({
    Key? key, 
    required this.classModel,
  }) : super(key: key);

  @override
  State<ClassDetailsScreen> createState() => _ClassDetailsScreenState();
}

class _ClassDetailsScreenState extends State<ClassDetailsScreen> {
  bool _isLoadingCount = false;
  int _studentsCount = 0;
  
  @override
  void initState() {
    super.initState();
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    
    // Only fetch student count if the user is a lecturer
    if (authProvider.isLecturer) {
      _loadStudentsCount();
    }
  }
  
  Future<void> _loadStudentsCount() async {
    setState(() {
      _isLoadingCount = true;
    });
    
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final supabaseService = authProvider.supabaseService;
      
      final count = await supabaseService.getClassStudentsCount(widget.classModel.id);
      
      setState(() {
        _studentsCount = count;
        _isLoadingCount = false;
      });
    } catch (e) {
      // Handle error
      setState(() {
        _isLoadingCount = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load students count: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  // Show confirmation dialog before leaving or deleting a class
  Future<bool> _showConfirmationDialog(String title, String message) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Confirm'),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
          ),
        ],
      ),
    );
    
    return result ?? false;
  }
  
  // Handle leaving a class (for students)
  Future<void> _leaveClass() async {
    final confirmed = await _showConfirmationDialog(
      'Leave Class',
      'Are you sure you want to leave this class? You will need the class code to rejoin.',
    );
    
    if (!confirmed) return;
    
    try {
      final classProvider = Provider.of<ClassProvider>(context, listen: false);
      await classProvider.leaveClass(widget.classModel.id);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You have left the class'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to leave class: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  // Handle deleting a class (for lecturers)
  Future<void> _deleteClass() async {
    final confirmed = await _showConfirmationDialog(
      'Delete Class',
      'Are you sure you want to delete this class? This action cannot be undone and will remove all students from the class.',
    );
    
    if (!confirmed) return;
    
    try {
      final classProvider = Provider.of<ClassProvider>(context, listen: false);
      await classProvider.deleteClass(widget.classModel.id);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Class deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete class: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final isLecturer = authProvider.currentUser is Lecturer;
    
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.classModel.name),
        centerTitle: true,
        actions: [
          // Add action button based on user role
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'leave') {
                _leaveClass();
              } else if (value == 'delete') {
                _deleteClass();
              }
            },
            itemBuilder: (context) => [
              if (isLecturer)
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Delete Class'),
                    ],
                  ),
                )
              else
                const PopupMenuItem(
                  value: 'leave',
                  child: Row(
                    children: [
                      Icon(Icons.exit_to_app, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Leave Class'),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Course details card
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
                        'Course Details',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const Divider(),
                      _buildInfoRow(
                        context, 
                        icon: Icons.book,
                        label: 'Course Name', 
                        value: widget.classModel.name,
                      ),
                      _buildInfoRow(
                        context, 
                        icon: Icons.code,
                        label: 'Course Code', 
                        value: widget.classModel.courseCode,
                      ),
                      _buildInfoRow(
                        context, 
                        icon: Icons.school,
                        label: 'Level', 
                        value: widget.classModel.level,
                      ),
                      _buildInfoRow(
                        context, 
                        icon: Icons.date_range,
                        label: 'Semester Period', 
                        value: '${DateFormat('MMM d, yyyy').format(widget.classModel.startDate)} - ${DateFormat('MMM d, yyyy').format(widget.classModel.endDate)}',
                      ),
                      
                      // Only show class code and student count for lecturers
                      if (isLecturer) ...[
                        const SizedBox(height: 16),
                        const Divider(),
                        // Student Count
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12.0),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.people,
                                size: 20,
                                color: Colors.blue,
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'Enrolled Students:',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 8),
                              _isLoadingCount
                                ? const SizedBox(
                                    width: 12,
                                    height: 12,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Text(
                                    '$_studentsCount',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                              if (!_isLoadingCount) ...[
                                const SizedBox(width: 4),
                                IconButton(
                                  icon: const Icon(Icons.refresh, size: 16),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  onPressed: _loadStudentsCount,
                                  tooltip: 'Refresh count',
                                ),
                              ]
                            ],
                          ),
                        ),
                        // Class Code
                        Row(
                          children: [
                            const Icon(
                              Icons.key,
                              color: Colors.amber,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'Class Code:',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                widget.classModel.code,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.copy),
                              onPressed: () {
                                Clipboard.setData(ClipboardData(text: widget.classModel.code));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Class code copied to clipboard'),
                                    duration: Duration(seconds: 1),
                                  ),
                                );
                              },
                              tooltip: 'Copy class code',
                            ),
                          ],
                        ),
                        const Text(
                          'Share this code with your students to allow them to join the class.',
                          style: TextStyle(
                            fontStyle: FontStyle.italic,
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Placeholder for future features
              // We'll use this space to add:
              // - For lecturers: list of students, post announcements, etc.
              // - For students: view announcements, assignments, etc.
              Text(
                isLecturer ? 'Class Management' : 'Class Activities',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Icon(
                        isLecturer ? Icons.people : Icons.assignment,
                        size: 48,
                        color: Colors.grey,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        isLecturer 
                          ? 'Features to manage students, post announcements, and create assignments will be added soon!'
                          : 'Features to view announcements, assignments, and course materials will be added soon!',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.grey,
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
  
  Widget _buildInfoRow(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 20,
            color: Theme.of(context).primaryColor,
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }
} 