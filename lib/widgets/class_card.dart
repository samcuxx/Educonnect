import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/class_model.dart';
import '../models/user_model.dart';
import '../providers/auth_provider.dart';
import '../services/supabase_service.dart';

class ClassCard extends StatefulWidget {
  final ClassModel classModel;
  final bool showCode;
  final VoidCallback onTap;

  const ClassCard({
    Key? key,
    required this.classModel,
    this.showCode = false,
    required this.onTap,
  }) : super(key: key);

  @override
  State<ClassCard> createState() => _ClassCardState();
}

class _ClassCardState extends State<ClassCard> {
  bool _isLoadingCount = false;
  int _studentsCount = 0;
  bool _showStudentCount = false;
  
  @override
  void initState() {
    super.initState();
    // Determine if we should show student count (only for lecturers)
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    _showStudentCount = authProvider.isLecturer;
    
    if (_showStudentCount) {
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
      
      if (mounted) {
        setState(() {
          _studentsCount = count;
          _isLoadingCount = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingCount = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 3,
      margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 2.0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      widget.classModel.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      widget.classModel.courseCode,
                      style: TextStyle(
                        color: Theme.of(context).primaryColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    widget.classModel.level,
                    style: const TextStyle(
                      color: Colors.grey,
                    ),
                  ),
                  // Show student count for lecturers
                  if (_showStudentCount) ...[
                    Row(
                      children: [
                        const Icon(
                          Icons.people,
                          size: 14,
                          color: Colors.grey,
                        ),
                        const SizedBox(width: 4),
                        _isLoadingCount
                            ? const SizedBox(
                                width: 10,
                                height: 10,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(
                                '$_studentsCount students',
                                style: const TextStyle(
                                  color: Colors.grey,
                                  fontSize: 12,
                                ),
                              ),
                      ],
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(
                    Icons.date_range,
                    size: 16,
                    color: Colors.grey,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${DateFormat('MMM d').format(widget.classModel.startDate)} - ${DateFormat('MMM d, yyyy').format(widget.classModel.endDate)}',
                    style: const TextStyle(
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
              if (widget.showCode) ...[
                const Divider(height: 24),
                Row(
                  children: [
                    const Icon(
                      Icons.key,
                      size: 16,
                      color: Colors.amber,
                    ),
                    const SizedBox(width: 4),
                    const Text(
                      'Class Code: ',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      widget.classModel.code,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.copy, size: 18),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: widget.classModel.code));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Class code copied to clipboard'),
                            duration: Duration(seconds: 1),
                          ),
                        );
                      },
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
} 