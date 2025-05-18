import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import 'package:open_filex/open_filex.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

import '../models/assignment_model.dart';
import '../models/submission_model.dart';
import '../providers/auth_provider.dart';
import '../services/supabase_service.dart';
import '../utils/app_theme.dart';

class SubmissionsScreen extends StatefulWidget {
  final AssignmentModel assignment;
  
  const SubmissionsScreen({
    Key? key,
    required this.assignment,
  }) : super(key: key);

  @override
  State<SubmissionsScreen> createState() => _SubmissionsScreenState();
}

class _SubmissionsScreenState extends State<SubmissionsScreen> {
  bool _isLoading = true;
  List<SubmissionModel> _submissions = [];
  
  // Tracking download progress and downloaded files
  Map<String, double> _submissionDownloadProgress = {};
  Map<String, String> _downloadedSubmissions = {};
  
  @override
  void initState() {
    super.initState();
    _loadSubmissions();
  }
  
  Future<void> _loadSubmissions() async {
      setState(() {
        _isLoading = true;
      });
      
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final supabaseService = authProvider.supabaseService;
      
      final submissions = await supabaseService.getAssignmentSubmissions(widget.assignment.id);
      
      setState(() {
        _submissions = submissions;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load submissions: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  // Download a submission file
  Future<void> _downloadSubmissionFile(SubmissionModel submission) async {
    if (_submissionDownloadProgress.containsKey(submission.id) || submission.fileUrl == null) {
      return; // Already downloading or no file URL
    }
    
    try {
      // Initialize progress
      setState(() {
        _submissionDownloadProgress[submission.id] = 0.0;
      });
      
      // Create the downloads directory if it doesn't exist
      final appDir = await getApplicationDocumentsDirectory();
      final downloadsDir = Directory('${appDir.path}/EduConnect/Downloads/Submissions');
      if (!await downloadsDir.exists()) {
        await downloadsDir.create(recursive: true);
      }
      
      // Extract the original filename from the URL
      final uri = Uri.parse(submission.fileUrl!);
      String fileName = path.basename(uri.path);
      
      // If the filename doesn't have an extension from the URL, try to add one
      if (!fileName.contains('.')) {
        final extension = _getExtensionFromFileType(submission.fileType);
        fileName = '${submission.id}$extension';
      }
      
      // Create file path
      final filePath = '${downloadsDir.path}/$fileName';
      final file = File(filePath);
      
      // Delete the file if it already exists
      if (await file.exists()) {
        await file.delete();
      }
      
      // Download the file with progress reporting
      final response = await http.Client().send(http.Request('GET', uri));
      final contentLength = response.contentLength ?? 0;
      
      final sink = file.openWrite();
      int bytesReceived = 0;
      
      await response.stream.listen((List<int> chunk) {
        sink.add(chunk);
        bytesReceived += chunk.length;
        
        if (contentLength > 0) {
          setState(() {
            _submissionDownloadProgress[submission.id] = bytesReceived / contentLength;
          });
        }
      }).asFuture();
      
      await sink.flush();
      await sink.close();
      
      // Save the file path
      setState(() {
        _downloadedSubmissions[submission.id] = filePath;
        _submissionDownloadProgress.remove(submission.id);
      });
      
      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${submission.studentName}\'s submission downloaded successfully'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      print('Error downloading submission file: $e');
      
      // Remove progress indicator
      setState(() {
        _submissionDownloadProgress.remove(submission.id);
      });
      
      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to download submission: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }
  
  // Open a downloaded submission file
  Future<void> _openSubmissionFile(SubmissionModel submission) async {
    try {
      final filePath = _downloadedSubmissions[submission.id];
      if (filePath == null) {
        throw Exception('File not found');
      }
      
      final file = File(filePath);
      if (!await file.exists()) {
        throw Exception('File no longer exists');
      }
      
      final result = await OpenFilex.open(filePath);
      if (result.type != ResultType.done) {
        throw Exception('Could not open file: ${result.message}');
      }
    } catch (e) {
      print('Error opening submission file: $e');
      
      // Remove from downloaded files if it doesn't exist
      if (e.toString().contains('no longer exists') || e.toString().contains('not found')) {
        setState(() {
          _downloadedSubmissions.remove(submission.id);
        });
      }
      
      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to open file: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }
  
  // Helper method to get file extension from file type
  String _getExtensionFromFileType(String fileType) {
    switch (fileType.toLowerCase()) {
      case 'pdf': return '.pdf';
      case 'word': return '.docx';
      case 'excel': return '.xlsx';
      case 'powerpoint': return '.pptx';
      case 'image': return '.jpg';
      case 'text': return '.txt';
      default: return '';
    }
  }
  
  // Get file icon and color based on file type
  IconData _getFileIconData(String fileType) {
    switch (fileType.toLowerCase()) {
      case 'pdf': return Icons.picture_as_pdf;
      case 'word': return Icons.description;
      case 'excel': return Icons.table_chart;
      case 'powerpoint': return Icons.slideshow;
      case 'image': return Icons.image;
      case 'text': return Icons.article;
      default: return Icons.insert_drive_file;
    }
  }
  
  Color _getFileColor(String fileType) {
    switch (fileType.toLowerCase()) {
      case 'pdf': return Colors.red;
      case 'word': return Colors.blue;
      case 'excel': return Colors.green;
      case 'powerpoint': return Colors.orange;
      case 'image': return Colors.purple;
      case 'text': return Colors.grey;
      default: return Colors.grey;
    }
  }
  
  // Check if submission was late
  bool _isSubmissionLate(DateTime submittedAt) {
    return submittedAt.isAfter(widget.assignment.deadline);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: isDark ? AppTheme.darkSurface : Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.assignment.title,
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black87,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              'Due ${DateFormat('MMM d, yyyy • h:mm a').format(widget.assignment.deadline)}',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white60 : Colors.black45,
              ),
            ),
          ],
        ),
      ),
      body: _isLoading
        ? const Center(child: CircularProgressIndicator())
          : _submissions.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                    Icons.assignment_outlined,
                    size: 64,
                    color: isDark ? Colors.white38 : Colors.black26,
                      ),
                      const SizedBox(height: 16),
                  Text(
                        'No submissions yet',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white70 : Colors.black54,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                    'Students have not submitted their work',
                        style: TextStyle(
                      color: isDark ? Colors.white60 : Colors.black45,
                        ),
                      ),
                    ],
                  ),
                )
          : CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.all(16),
                  sliver: SliverToBoxAdapter(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: isDark ? [
                            AppTheme.darkPrimaryStart.withOpacity(0.1),
                            AppTheme.darkPrimaryEnd.withOpacity(0.05),
                          ] : [
                            AppTheme.lightPrimaryStart.withOpacity(0.1),
                            AppTheme.lightPrimaryEnd.withOpacity(0.05),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark 
                            ? AppTheme.darkPrimaryStart.withOpacity(0.2)
                            : AppTheme.lightPrimaryStart.withOpacity(0.2),
                        ),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                                  Text(
                                    'Total Submissions',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: isDark ? Colors.white60 : Colors.black45,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _submissions.length.toString(),
                                style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: isDark ? Colors.white : Colors.black87,
                                ),
                              ),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: (isDark ? AppTheme.darkPrimaryStart : AppTheme.lightPrimaryStart).withOpacity(0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.assignment_turned_in,
                                  color: isDark ? AppTheme.darkPrimaryStart : AppTheme.lightPrimaryStart,
                                  size: 24,
                                ),
                              ),
                          ],
                        ),
                          const SizedBox(height: 16),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: LinearProgressIndicator(
                              value: widget.assignment.totalStudents > 0
                                ? _submissions.length / widget.assignment.totalStudents
                                : 0,
                              backgroundColor: isDark ? Colors.white12 : Colors.black12,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                isDark ? AppTheme.darkPrimaryStart : AppTheme.lightPrimaryStart,
                              ),
                              minHeight: 8,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${(widget.assignment.totalStudents > 0 ? (_submissions.length / widget.assignment.totalStudents * 100) : 0).toStringAsFixed(1)}% of students submitted',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? Colors.white60 : Colors.black45,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final submission = _submissions[index];
                        final bool isDownloading = _submissionDownloadProgress.containsKey(submission.id);
                        final bool isDownloaded = _downloadedSubmissions.containsKey(submission.id);
                        
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: submission.fileUrl != null && isDownloaded 
                                ? () => _openSubmissionFile(submission)
                                : null,
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.02),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isDark ? Colors.white12 : Colors.black12,
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 20,
                                          backgroundColor: (isDark ? AppTheme.darkPrimaryStart : AppTheme.lightPrimaryStart).withOpacity(0.1),
                                          child: Text(
                                            submission.studentName[0].toUpperCase(),
                                            style: TextStyle(
                                              color: isDark ? AppTheme.darkPrimaryStart : AppTheme.lightPrimaryStart,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                submission.studentName,
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  color: isDark ? Colors.white : Colors.black87,
                                                ),
                                              ),
                                              Text(
                                                'Submitted ${DateFormat('MMM d, yyyy • h:mm a').format(submission.submittedAt)}',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: isDark ? Colors.white60 : Colors.black45,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: submission.submittedAt.isBefore(widget.assignment.deadline)
                                              ? Colors.green.withOpacity(0.1)
                                              : Colors.orange.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            submission.submittedAt.isBefore(widget.assignment.deadline)
                                              ? 'On Time'
                                              : 'Late',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: submission.submittedAt.isBefore(widget.assignment.deadline)
                                                ? Colors.green
                                                : Colors.orange,
                                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                                      ],
                                    ),
                                    if (submission.fileUrl != null) ...[
                                      const SizedBox(height: 12),
                                      Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.02),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.all(8),
                                              decoration: BoxDecoration(
                                                color: _getFileColor(submission.fileType).withOpacity(0.1),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Icon(
                                                _getFileIconData(submission.fileType),
                                                color: _getFileColor(submission.fileType),
                                                size: 16,
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    'Submission File',
                                                    style: TextStyle(
                                                      fontWeight: FontWeight.w500,
                                                      color: isDark ? Colors.white : Colors.black87,
                                                    ),
                                                  ),
                                                  Text(
                                                    submission.fileType,
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      color: isDark ? Colors.white60 : Colors.black45,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            if (isDownloaded)
                                              TextButton.icon(
                                                icon: const Icon(Icons.open_in_new, size: 16),
                                                label: const Text('Open'),
                                                onPressed: () => _openSubmissionFile(submission),
                                                style: TextButton.styleFrom(
                                                  foregroundColor: isDark ? AppTheme.darkPrimaryStart : AppTheme.lightPrimaryStart,
                                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                                ),
                                              )
                                            else if (isDownloading)
                                              Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  SizedBox(
                                                    width: 16,
                                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                                      valueColor: AlwaysStoppedAnimation<Color>(
                                                        isDark ? AppTheme.darkPrimaryStart : AppTheme.lightPrimaryStart
                                                      ),
                                                      value: _submissionDownloadProgress[submission.id],
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Text(
                                                    '${(_submissionDownloadProgress[submission.id]! * 100).toStringAsFixed(0)}%',
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      color: isDark ? AppTheme.darkPrimaryStart : AppTheme.lightPrimaryStart,
                                    ),
                                                  ),
                                                ],
                                              )
                                            else
                                              TextButton.icon(
                                                icon: const Icon(Icons.download, size: 16),
                                                label: const Text('Download'),
                                                onPressed: () => _downloadSubmissionFile(submission),
                                                style: TextButton.styleFrom(
                                                  foregroundColor: isDark ? AppTheme.darkPrimaryStart : AppTheme.lightPrimaryStart,
                                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                      ),
                    );
                  },
                      childCount: _submissions.length,
                    ),
                  ),
                ),
                const SliverPadding(padding: EdgeInsets.only(bottom: 16)),
              ],
                ),
    );
  }
} 