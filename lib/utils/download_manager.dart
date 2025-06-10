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
  // Resource download tracking
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

      // Save the file path
      downloadedFiles[resource.id] = filePath;
      downloadProgress.remove(resource.id);

      onProgressUpdate(Map.from(downloadProgress));
      onComplete(Map.from(downloadedFiles));

      // Save the updated list of downloaded files
      await _saveDownloadedFiles(downloadedFiles, resource.id.split('_')[0]);

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

      // Save the file path
      downloadedAssignments[assignment.id] = filePath;
      assignmentDownloadProgress.remove(assignment.id);

      onProgressUpdate(Map.from(assignmentDownloadProgress));
      onComplete(Map.from(downloadedAssignments));

      // Update the stored list of downloaded files
      await _saveDownloadedAssignments(
        downloadedAssignments,
        assignment.id.split('_')[0],
      );

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
      final response = await http.Client().send(http.Request('GET', uri));
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

      // Save the file path
      downloadedSubmissions[submission.id] = filePath;
      submissionDownloadProgress.remove(submission.id);

      onProgressUpdate(Map.from(submissionDownloadProgress));
      onComplete(Map.from(downloadedSubmissions));

      // Update the stored list of downloaded files
      await _saveDownloadedSubmissions(
        downloadedSubmissions,
        submission.id.split('_')[0],
      );

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

  // Load downloaded resources from SharedPreferences
  Future<Map<String, String>> loadDownloadedFiles(String classId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final fileMap = prefs.getString('downloaded_resources_$classId');

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
          await _saveDownloadedFiles(map, classId);
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

  // Load downloaded assignments from SharedPreferences
  Future<Map<String, String>> loadDownloadedAssignments(String classId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final fileMap = prefs.getString('downloaded_assignments_$classId');

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
          await _saveDownloadedAssignments(map, classId);
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

  // Load downloaded submissions from SharedPreferences
  Future<Map<String, String>> loadDownloadedSubmissions(String classId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final fileMap = prefs.getString('downloaded_submissions_$classId');

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
          await _saveDownloadedSubmissions(map, classId);
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

  // Save downloaded resources to SharedPreferences
  Future<void> _saveDownloadedFiles(
    Map<String, String> files,
    String classId,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'downloaded_resources_$classId',
        json.encode(files),
      );
    } catch (e) {
      print('Error saving downloaded files: $e');
    }
  }

  // Save downloaded assignments to SharedPreferences
  Future<void> _saveDownloadedAssignments(
    Map<String, String> files,
    String classId,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'downloaded_assignments_$classId',
        json.encode(files),
      );
    } catch (e) {
      print('Error saving downloaded assignments: $e');
    }
  }

  // Save downloaded submissions to SharedPreferences
  Future<void> _saveDownloadedSubmissions(
    Map<String, String> files,
    String classId,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'downloaded_submissions_$classId',
        json.encode(files),
      );
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
}
