class SubmissionModel {
  final String id;
  final String assignmentId;
  final String studentId;
  final String studentName;
  final String? studentNumber; // Added student index number
  final String? fileUrl;
  final DateTime submittedAt;
  final String fileType;
  
  SubmissionModel({
    required this.id,
    required this.assignmentId,
    required this.studentId,
    required this.studentName,
    this.studentNumber,
    this.fileUrl,
    required this.submittedAt,
    required this.fileType,
  });

  factory SubmissionModel.fromJson(Map<String, dynamic> json) {
    return SubmissionModel(
      id: json['id'],
      assignmentId: json['assignment_id'],
      studentId: json['student_id'],
      studentName: json['student_name'] ?? 'Student',
      studentNumber: json['student_number'],
      fileUrl: json['file_url'],
      submittedAt: DateTime.parse(json['submitted_at']),
      fileType: json['file_type'] ?? _determineFileType(json['file_url']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'assignment_id': assignmentId,
      'student_id': studentId,
      'student_name': studentName,
      'student_number': studentNumber,
      'file_url': fileUrl,
      'submitted_at': submittedAt.toIso8601String(),
      'file_type': fileType,
    };
  }

  // Determine file type based on the URL extension
  static String _determineFileType(String? url) {
    if (url == null) return 'None';
    
    final extension = url.split('.').last.toLowerCase();
    
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
      case 'txt':
        return 'Text';
      case 'jpg':
      case 'jpeg':
      case 'png':
        return 'Image';
      default:
        return 'Document';
    }
  }
} 