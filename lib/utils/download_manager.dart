import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:open_filex/open_filex.dart';
import '../models/resource_model.dart';
import '../models/assignment_model.dart';
import '../models/submission_model.dart';
import 'file_utils.dart';

class DownloadManager {
  // Singleton instance
  static final DownloadManager _instance = DownloadManager._internal();

  factory DownloadManager() => _instance;

  DownloadManager._internal();

  // Unified global download tracking - all downloads are stored in global keys
  static const String _globalResourcesKey = 'downloaded_resources_all';
  static const String _globalAssignmentsKey = 'downloaded_assignments_all';
  static const String _globalSubmissionsKey = 'downloaded_submissions_all';

  // Progress tracking (in-memory)
  final Map<String, double> downloadProgress = {};
  final Map<String, String> downloadedFiles = {};

  // Assignment download tracking
  final Map<String, double> assignmentDownloadProgress = {};
  final Map<String, String> downloadedAssignments = {};

  // Submission download tracking
  final Map<String, double> submissionDownloadProgress = {};
  final Map<String, String> downloadedSubmissions = {};

  // Download a resource file
  Future<void> downloadResource({
    required ResourceModel resource,
    required Function(Map<String, double>) onProgressUpdate,
    required Function(Map<String, String>) onComplete,
    required BuildContext context,
  }) async {
    if (downloadProgress.containsKey(resource.id)) {
      return; // Already downloading
    }

    try {
      // Initialize progress
      downloadProgress[resource.id] = 0.0;
      onProgressUpdate(Map.from(downloadProgress));

      // Create the downloads directory if it doesn't exist
      final appDir = await getApplicationDocumentsDirectory();
      final downloadsDir = Directory('${appDir.path}/EduConnect/Downloads');
      if (!await downloadsDir.exists()) {
        await downloadsDir.create(recursive: true);
      }

      // Extract the original filename from the URL
      final uri = Uri.parse(resource.fileUrl);
      String fileName = path.basename(uri.path);

      // If the filename doesn't have an extension from the URL, try to add one based on resource.fileType
      if (!fileName.contains('.')) {
        final extension = _getExtensionFromFileType(resource.fileType);
        fileName = '${resource.id}$extension';
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
          downloadProgress[resource.id] = bytesReceived / contentLength;
          onProgressUpdate(Map.from(downloadProgress));
        }
      }).asFuture();

      await sink.flush();
      await sink.close();

      // Save the file path globally
      downloadedFiles[resource.id] = filePath;
      downloadProgress.remove(resource.id);

      onProgressUpdate(Map.from(downloadProgress));
      onComplete(Map.from(downloadedFiles));

      // Save the updated list of downloaded files to global storage
      await _saveDownloadedFiles(downloadedFiles);

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${resource.title} downloaded successfully'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      print('Error downloading file: $e');

      // Remove progress indicator
      downloadProgress.remove(resource.id);
      onProgressUpdate(Map.from(downloadProgress));

      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to download ${resource.title}: ${e.toString()}',
          ),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  // Download an assignment file
  Future<void> downloadAssignment({
    required AssignmentModel assignment,
    required Function(Map<String, double>) onProgressUpdate,
    required Function(Map<String, String>) onComplete,
    required BuildContext context,
  }) async {
    if (assignmentDownloadProgress.containsKey(assignment.id) ||
        assignment.fileUrl == null) {
      return; // Already downloading or no file URL
    }

    try {
      // Initialize progress
      assignmentDownloadProgress[assignment.id] = 0.0;
      onProgressUpdate(Map.from(assignmentDownloadProgress));

      // Create the downloads directory if it doesn't exist
      final appDir = await getApplicationDocumentsDirectory();
      final downloadsDir = Directory(
        '${appDir.path}/EduConnect/Downloads/Assignments',
      );
      if (!await downloadsDir.exists()) {
        await downloadsDir.create(recursive: true);
      }

      // Extract the original filename from the URL
      final uri = Uri.parse(assignment.fileUrl!);
      String fileName = path.basename(uri.path);

      // If the filename doesn't have an extension from the URL, try to add one based on assignment.fileType
      if (!fileName.contains('.')) {
        final extension = _getExtensionFromFileType(assignment.fileType);
        fileName = '${assignment.id}$extension';
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
          assignmentDownloadProgress[assignment.id] =
              bytesReceived / contentLength;
          onProgressUpdate(Map.from(assignmentDownloadProgress));
        }
      }).asFuture();

      await sink.flush();
      await sink.close();

      // Save the file path globally
      downloadedAssignments[assignment.id] = filePath;
      assignmentDownloadProgress.remove(assignment.id);

      onProgressUpdate(Map.from(assignmentDownloadProgress));
      onComplete(Map.from(downloadedAssignments));

      // Update the global storage for downloaded assignments
      await _saveDownloadedAssignments(downloadedAssignments);

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${assignment.title} downloaded successfully'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      print('Error downloading assignment file: $e');

      // Remove progress indicator
      assignmentDownloadProgress.remove(assignment.id);
      onProgressUpdate(Map.from(assignmentDownloadProgress));

      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to download ${assignment.title}: ${e.toString()}',
          ),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  // Download a submission file
  Future<void> downloadSubmission({
    required SubmissionModel submission,
    required Function(Map<String, double>) onProgressUpdate,
    required Function(Map<String, String>) onComplete,
    required BuildContext context,
  }) async {
    if (submissionDownloadProgress.containsKey(submission.id) ||
        submission.fileUrl == null) {
      return; // Already downloading or no file URL
    }

    try {
      // Initialize progress
      submissionDownloadProgress[submission.id] = 0.0;
      onProgressUpdate(Map.from(submissionDownloadProgress));

      // Create the downloads directory if it doesn't exist
      final appDir = await getApplicationDocumentsDirectory();
      final downloadsDir = Directory(
        '${appDir.path}/EduConnect/Downloads/Submissions',
      );
      if (!await downloadsDir.exists()) {
        await downloadsDir.create(recursive: true);
      }

      // Extract the original filename from the URL
      final uri = Uri.parse(submission.fileUrl!);
      String fileName = path.basename(uri.path);

      // If the filename doesn't have an extension from the URL, try to add one based on submission.fileType
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
      final client = http.Client();
      try {
        final response = await client.send(http.Request('GET', uri));
        final contentLength = response.contentLength ?? 0;

        final sink = file.openWrite();
        int bytesReceived = 0;

        await response.stream.listen((List<int> chunk) {
          sink.add(chunk);
          bytesReceived += chunk.length;

          if (contentLength > 0) {
            submissionDownloadProgress[submission.id] =
                bytesReceived / contentLength;
            onProgressUpdate(Map.from(submissionDownloadProgress));
          }
        }).asFuture();

        await sink.flush();
        await sink.close();

        // Save the file path globally
        downloadedSubmissions[submission.id] = filePath;

        // CRITICAL FIX: Also save the file path under the assignment ID for student's own submission
        // This allows students to access their own submission via the assignment
        if (submission.assignmentId != null &&
            submission.assignmentId!.isNotEmpty) {
          downloadedSubmissions[submission.assignmentId!] = filePath;
        }

        submissionDownloadProgress.remove(submission.id);

        onProgressUpdate(Map.from(submissionDownloadProgress));
        onComplete(Map.from(downloadedSubmissions));

        // Update the global storage for downloaded submissions
        await _saveDownloadedSubmissions(downloadedSubmissions);

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${submission.studentName}\'s submission downloaded successfully',
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      } finally {
        client.close();
      }
    } catch (e) {
      print('Error downloading submission file: $e');

      // Remove progress indicator
      submissionDownloadProgress.remove(submission.id);
      onProgressUpdate(Map.from(submissionDownloadProgress));

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

  // Open a downloaded file
  Future<void> openFile(String? filePath, BuildContext context) async {
    try {
      if (filePath == null) {
        throw Exception('File path is null');
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
      print('Error opening file: $e');

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

  // Load ALL downloaded resources globally (not class-specific)
  Future<Map<String, String>> loadDownloadedFiles() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final fileMap = prefs.getString(_globalResourcesKey);

      if (fileMap != null) {
        final map = Map<String, String>.from(json.decode(fileMap));

        // Verify files still exist
        for (final resourceId in map.keys.toList()) {
          final filePath = map[resourceId];
          if (filePath != null) {
            final file = File(filePath);
            if (!await file.exists()) {
              map.remove(resourceId);
            }
          }
        }

        // Save changes if any files were removed
        if (map.length != json.decode(fileMap).length) {
          await _saveDownloadedFiles(map);
        }

        downloadedFiles.clear();
        downloadedFiles.addAll(map);
        return Map.from(map);
      }
      return {};
    } catch (e) {
      print('Error loading downloaded files: $e');
      return {};
    }
  }

  // Load ALL downloaded assignments globally (not class-specific)
  Future<Map<String, String>> loadDownloadedAssignments() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final fileMap = prefs.getString(_globalAssignmentsKey);

      if (fileMap != null) {
        final map = Map<String, String>.from(json.decode(fileMap));

        // Verify files still exist
        for (final assignmentId in map.keys.toList()) {
          final filePath = map[assignmentId];
          if (filePath != null) {
            final file = File(filePath);
            if (!await file.exists()) {
              map.remove(assignmentId);
            }
          }
        }

        // Save changes if any files were removed
        if (map.length != json.decode(fileMap).length) {
          await _saveDownloadedAssignments(map);
        }

        downloadedAssignments.clear();
        downloadedAssignments.addAll(map);
        return Map.from(map);
      }
      return {};
    } catch (e) {
      print('Error loading downloaded assignments: $e');
      return {};
    }
  }

  // Load ALL downloaded submissions globally (not class-specific)
  Future<Map<String, String>> loadDownloadedSubmissions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final fileMap = prefs.getString(_globalSubmissionsKey);

      if (fileMap != null) {
        final map = Map<String, String>.from(json.decode(fileMap));

        // Verify files still exist
        for (final submissionId in map.keys.toList()) {
          final filePath = map[submissionId];
          if (filePath != null) {
            final file = File(filePath);
            if (!await file.exists()) {
              map.remove(submissionId);
            }
          }
        }

        // Save changes if any files were removed
        if (map.length != json.decode(fileMap).length) {
          await _saveDownloadedSubmissions(map);
        }

        downloadedSubmissions.clear();
        downloadedSubmissions.addAll(map);
        return Map.from(map);
      }
      return {};
    } catch (e) {
      print('Error loading downloaded submissions: $e');
      return {};
    }
  }

  // Save downloaded resources to global SharedPreferences
  Future<void> _saveDownloadedFiles(Map<String, String> files) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_globalResourcesKey, json.encode(files));
    } catch (e) {
      print('Error saving downloaded files: $e');
    }
  }

  // Save downloaded assignments to global SharedPreferences
  Future<void> _saveDownloadedAssignments(Map<String, String> files) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_globalAssignmentsKey, json.encode(files));
    } catch (e) {
      print('Error saving downloaded assignments: $e');
    }
  }

  // Save downloaded submissions to global SharedPreferences
  Future<void> _saveDownloadedSubmissions(Map<String, String> files) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_globalSubmissionsKey, json.encode(files));
    } catch (e) {
      print('Error saving downloaded submissions: $e');
    }
  }

  // Helper method to get file extension from file type
  String _getExtensionFromFileType(String fileType) {
    switch (fileType.toLowerCase()) {
      case 'pdf':
        return '.pdf';
      case 'word':
        return '.docx';
      case 'excel':
        return '.xlsx';
      case 'powerpoint':
        return '.pptx';
      case 'image':
        return '.jpg';
      case 'text':
        return '.txt';
      default:
        return '';
    }
  }

  // Download a student's own submission by assignment ID
  Future<void> downloadStudentSubmission({
    required String assignmentId,
    required String studentId,
    required String studentName,
    required String fileUrl,
    required String fileType,
    required Function(Map<String, double>) onProgressUpdate,
    required Function(Map<String, String>) onComplete,
    required BuildContext context,
  }) async {
    if (submissionDownloadProgress.containsKey(assignmentId) ||
        fileUrl.isEmpty) {
      return; // Already downloading or no file URL
    }

    // Create a temporary submission model to use with the existing download method
    final submission = SubmissionModel(
      id: "temp_${assignmentId}_$studentId",
      assignmentId: assignmentId,
      studentId: studentId,
      studentName: studentName,
      submittedAt: DateTime.now(),
      fileUrl: fileUrl,
      fileType: fileType,
    );

    // Use the existing download method
    await downloadSubmission(
      submission: submission,
      onProgressUpdate: onProgressUpdate,
      onComplete: onComplete,
      context: context,
    );
  }

  // Get combined downloaded files map that includes resources, assignments, and submissions
  Future<Map<String, String>> getAllDownloadedFiles() async {
    final resources = await loadDownloadedFiles();
    final assignments = await loadDownloadedAssignments();
    final submissions = await loadDownloadedSubmissions();

    final combined = <String, String>{};
    combined.addAll(resources);
    combined.addAll(assignments);
    combined.addAll(submissions);

    return combined;
  }
}
