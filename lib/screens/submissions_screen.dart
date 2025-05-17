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
  Map<String, double> _downloadProgress = {};
  Map<String, String> _downloadedFiles = {};
  
  @override
  void initState() {
    super.initState();
    _loadSubmissions();
    _loadDownloadedFiles();
  }
  
  // Load downloaded files info
  Future<void> _loadDownloadedFiles() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final fileMap = prefs.getString('downloaded_submissions_${widget.assignment.id}');
      
      if (fileMap != null) {
        setState(() {
          _downloadedFiles = Map<String, String>.from(json.decode(fileMap));
        });
        
        // Verify files still exist
        for (final submissionId in _downloadedFiles.keys.toList()) {
          final filePath = _downloadedFiles[submissionId];
          if (filePath != null) {
            final file = File(filePath);
            if (!await file.exists()) {
              setState(() {
                _downloadedFiles.remove(submissionId);
              });
            }
          }
        }
        
        // Save changes if any files were removed
        await _saveDownloadedFiles();
      }
    } catch (e) {
      print('Error loading downloaded submissions: $e');
    }
  }
  
  // Save downloaded files info
  Future<void> _saveDownloadedFiles() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'downloaded_submissions_${widget.assignment.id}',
        json.encode(_downloadedFiles)
      );
    } catch (e) {
      print('Error saving downloaded submissions: $e');
    }
  }
  
  Future<void> _loadSubmissions() async {
    try {
      setState(() {
        _isLoading = true;
      });
      
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
    if (_downloadProgress.containsKey(submission.id) || submission.fileUrl == null) {
      return; // Already downloading or no file URL
    }
    
    try {
      // Initialize progress
      setState(() {
        _downloadProgress[submission.id] = 0.0;
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
            _downloadProgress[submission.id] = bytesReceived / contentLength;
          });
        }
      }).asFuture();
      
      await sink.flush();
      await sink.close();
      
      // Save the file path
      setState(() {
        _downloadedFiles[submission.id] = filePath;
        _downloadProgress.remove(submission.id);
      });
      
      // Update the stored list of downloaded files
      await _saveDownloadedFiles();
      
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
        _downloadProgress.remove(submission.id);
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
      final filePath = _downloadedFiles[submission.id];
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
          _downloadedFiles.remove(submission.id);
        });
        await _saveDownloadedFiles();
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
    switch (fileType) {
      case 'PDF':
        return Icons.picture_as_pdf;
      case 'Word':
        return Icons.description;
      case 'Excel':
        return Icons.table_chart;
      case 'PowerPoint':
        return Icons.slideshow;
      case 'Image':
        return Icons.image;
      case 'Text':
        return Icons.article;
      default:
        return Icons.insert_drive_file;
    }
  }
  
  Color _getFileColor(String fileType) {
    switch (fileType) {
      case 'PDF': return Colors.red;
      case 'Word': return Colors.blue;
      case 'Excel': return Colors.green;
      case 'PowerPoint': return Colors.orange;
      case 'Image': return Colors.purple;
      case 'Text': return Colors.grey;
      default: return Colors.grey;
    }
  }
  
  // Check if submission was late
  bool _isSubmissionLate(DateTime submittedAt) {
    return submittedAt.isAfter(widget.assignment.deadline);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Submissions'),
            Text(
              widget.assignment.title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadSubmissions,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _submissions.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.assignment_late_outlined,
                        size: 72,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'No submissions yet',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Students have not submitted\nthis assignment yet',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: _submissions.length,
                  itemBuilder: (context, index) {
                    final submission = _submissions[index];
                    final isLate = _isSubmissionLate(submission.submittedAt);
                    
                    return Card(
                      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      elevation: 1,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ListTile(
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        onTap: submission.fileUrl != null
                          ? _downloadedFiles.containsKey(submission.id)
                              ? () => _openSubmissionFile(submission)
                              : () => _downloadSubmissionFile(submission)
                          : null,
                        title: Row(
                          children: [
                            Expanded(
                              child: Text(
                                submission.studentName,
                                style: TextStyle(
                                  fontWeight: FontWeight.w500,
                                  fontSize: 16,
                                  color: isLate ? Colors.red : null,
                                ),
                              ),
                            ),
                            if (submission.studentNumber != null)
                              Text(
                                submission.studentNumber!,
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontWeight: FontWeight.w400,
                                  fontSize: 14,
                                ),
                              ),
                          ],
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            DateFormat('MMM d, yyyy • h:mm a').format(submission.submittedAt),
                            style: TextStyle(
                              fontSize: 12,
                              color: isLate ? Colors.red.withOpacity(0.8) : Colors.grey[600],
                            ),
                          ),
                        ),
                        trailing: submission.fileUrl != null
                          ? _downloadedFiles.containsKey(submission.id)
                              ? Icon(
                                  Icons.visibility,
                                  color: Theme.of(context).primaryColor,
                                )
                              : _downloadProgress.containsKey(submission.id)
                                ? SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      value: _downloadProgress[submission.id],
                                      strokeWidth: 2,
                                      color: Theme.of(context).primaryColor,
                                    ),
                                  )
                                : Icon(
                                    Icons.download,
                                    color: Theme.of(context).primaryColor,
                                  )
                          : null,
                      ),
                    );
                  },
                ),
    );
  }
} 