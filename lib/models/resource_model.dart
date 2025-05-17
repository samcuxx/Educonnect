class ResourceModel {
  final String id;
  final String classId;
  final String fileUrl;
  final String title;
  final String uploadedBy;
  final String uploadedByName; // Name of the lecturer who uploaded
  final DateTime createdAt;
  final String fileType; // PDF, DOCX, etc.

  ResourceModel({
    required this.id,
    required this.classId,
    required this.fileUrl,
    required this.title,
    required this.uploadedBy,
    required this.uploadedByName,
    required this.createdAt,
    required this.fileType,
  });

  factory ResourceModel.fromJson(Map<String, dynamic> json) {
    return ResourceModel(
      id: json['id'],
      classId: json['class_id'],
      fileUrl: json['file_url'],
      title: json['title'],
      uploadedBy: json['uploaded_by'],
      uploadedByName: json['uploaded_by_name'] ?? 'Lecturer', // Fallback if name not provided
      createdAt: DateTime.parse(json['created_at']),
      fileType: json['file_type'] ?? _determineFileType(json['file_url']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'class_id': classId,
      'file_url': fileUrl,
      'title': title,
      'uploaded_by': uploadedBy,
      'created_at': createdAt.toIso8601String(),
    };
  }

  // Determine file type based on the URL extension
  static String _determineFileType(String url) {
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