import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class FileUtils {
  // Get file icon based on file extension
  static IconData getFileIcon(String fileUrl) {
    final extension = _getFileExtension(fileUrl).toLowerCase();

    switch (extension) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'doc':
      case 'docx':
        return Icons.description;
      case 'xls':
      case 'xlsx':
        return Icons.table_chart;
      case 'ppt':
      case 'pptx':
        return Icons.slideshow;
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
      case 'bmp':
      case 'webp':
        return Icons.image;
      case 'mp4':
      case 'avi':
      case 'mov':
      case 'mkv':
        return Icons.video_file;
      case 'mp3':
      case 'wav':
      case 'aac':
        return Icons.audio_file;
      case 'zip':
      case 'rar':
      case '7z':
        return Icons.archive;
      case 'txt':
        return Icons.text_snippet;
      default:
        return Icons.insert_drive_file;
    }
  }

  // Get file type display name
  static String getFileType(String fileUrl) {
    final extension = _getFileExtension(fileUrl).toLowerCase();

    switch (extension) {
      case 'pdf':
        return 'PDF';
      case 'doc':
      case 'docx':
        return 'Word';
      case 'xls':
      case 'xlsx':
        return 'Excel';
      case 'ppt':
      case 'pptx':
        return 'PowerPoint';
      case 'jpg':
      case 'jpeg':
        return 'JPEG';
      case 'png':
        return 'PNG';
      case 'gif':
        return 'GIF';
      case 'mp4':
        return 'MP4';
      case 'avi':
        return 'AVI';
      case 'mov':
        return 'MOV';
      case 'mp3':
        return 'MP3';
      case 'wav':
        return 'WAV';
      case 'zip':
        return 'ZIP';
      case 'rar':
        return 'RAR';
      case 'txt':
        return 'Text';
      default:
        return extension.toUpperCase().isNotEmpty
            ? extension.toUpperCase()
            : 'File';
    }
  }

  // Get file size display (if size is provided)
  static String formatFileSize(int? bytes) {
    if (bytes == null || bytes <= 0) return 'Unknown size';

    const suffixes = ['B', 'KB', 'MB', 'GB'];
    var i = 0;
    double size = bytes.toDouble();

    while (size >= 1024 && i < suffixes.length - 1) {
      size /= 1024;
      i++;
    }

    return '${size.toStringAsFixed(size >= 100 ? 0 : 1)} ${suffixes[i]}';
  }

  // Format date for display
  static String formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      // Today - show time
      return DateFormat('HH:mm').format(date);
    } else if (difference.inDays == 1) {
      // Yesterday
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      // This week - show day
      return DateFormat('EEEE').format(date);
    } else if (difference.inDays < 365) {
      // This year - show month and day
      return DateFormat('MMM d').format(date);
    } else {
      // Previous years - show full date
      return DateFormat('MMM d, y').format(date);
    }
  }

  // Format date with time for detailed view
  static String formatDateTime(DateTime date) {
    return DateFormat('MMM d, y • HH:mm').format(date);
  }

  // Check if file is an image
  static bool isImage(String fileUrl) {
    final extension = _getFileExtension(fileUrl).toLowerCase();
    return ['jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp'].contains(extension);
  }

  // Check if file is a video
  static bool isVideo(String fileUrl) {
    final extension = _getFileExtension(fileUrl).toLowerCase();
    return ['mp4', 'avi', 'mov', 'mkv', 'wmv', 'flv'].contains(extension);
  }

  // Check if file is audio
  static bool isAudio(String fileUrl) {
    final extension = _getFileExtension(fileUrl).toLowerCase();
    return ['mp3', 'wav', 'aac', 'ogg', 'flac'].contains(extension);
  }

  // Check if file is a document
  static bool isDocument(String fileUrl) {
    final extension = _getFileExtension(fileUrl).toLowerCase();
    return [
      'pdf',
      'doc',
      'docx',
      'xls',
      'xlsx',
      'ppt',
      'pptx',
      'txt',
    ].contains(extension);
  }

  // Get file extension from URL
  static String _getFileExtension(String fileUrl) {
    try {
      final uri = Uri.parse(fileUrl);
      final path = uri.path;
      final lastDotIndex = path.lastIndexOf('.');

      if (lastDotIndex != -1 && lastDotIndex < path.length - 1) {
        return path.substring(lastDotIndex + 1);
      }

      return '';
    } catch (e) {
      return '';
    }
  }

  // Get file name from URL
  static String getFileName(String fileUrl) {
    try {
      final uri = Uri.parse(fileUrl);
      final path = uri.path;
      final lastSlashIndex = path.lastIndexOf('/');

      if (lastSlashIndex != -1 && lastSlashIndex < path.length - 1) {
        return path.substring(lastSlashIndex + 1);
      }

      return 'Unknown file';
    } catch (e) {
      return 'Unknown file';
    }
  }

  // Get color for file type
  static Color getFileTypeColor(String fileUrl, {bool isDark = false}) {
    final extension = _getFileExtension(fileUrl).toLowerCase();

    switch (extension) {
      case 'pdf':
        return Colors.red;
      case 'doc':
      case 'docx':
        return Colors.blue;
      case 'xls':
      case 'xlsx':
        return Colors.green;
      case 'ppt':
      case 'pptx':
        return Colors.orange;
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
        return Colors.purple;
      case 'mp4':
      case 'avi':
      case 'mov':
        return Colors.indigo;
      case 'mp3':
      case 'wav':
        return Colors.teal;
      case 'zip':
      case 'rar':
        return Colors.brown;
      default:
        return isDark ? Colors.grey[400]! : Colors.grey[600]!;
    }
  }
}
