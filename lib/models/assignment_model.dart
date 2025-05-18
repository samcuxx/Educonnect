class AssignmentModel {
  final String id;
  final String classId;
  final String title;
  final String? description;  // Optional text description
  final String? fileUrl;      // Optional file attachment
  final String assignedBy;
  final String assignedByName;
  final DateTime createdAt;
  final DateTime deadline;
  final String fileType;      // For document attachments
  final int totalStudents;

  AssignmentModel({
    required this.id,
    required this.classId,
    required this.title,
    this.description,
    this.fileUrl,
    required this.assignedBy,
    required this.assignedByName,
    required this.createdAt,
    required this.deadline,
    required this.fileType,
    required this.totalStudents,
  });

  factory AssignmentModel.fromJson(Map<String, dynamic> json) {
    return AssignmentModel(
      id: json['id'],
      classId: json['class_id'],
      title: json['title'],
      description: json['description'],
      fileUrl: json['file_url'],
      assignedBy: json['assigned_by'],
      assignedByName: json['assigned_by_name'] ?? 'Lecturer',
      createdAt: DateTime.parse(json['created_at']),
      deadline: DateTime.parse(json['deadline']),
      fileType: json['file_type'] ?? _determineFileType(json['file_url']),
      totalStudents: json['total_students'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'class_id': classId,
      'title': title,
      'description': description,
      'file_url': fileUrl,
      'assigned_by': assignedBy,
      'assigned_by_name': assignedByName,
      'created_at': createdAt.toIso8601String(),
      'deadline': deadline.toIso8601String(),
      'file_type': fileType,
      'total_students': totalStudents,
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