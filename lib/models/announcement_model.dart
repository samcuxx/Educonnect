class AnnouncementModel {
  final String id;
  final String classId;
  final String title;
  final String message;
  final String postedBy;
  final String postedByName; // Name of the lecturer who posted
  final DateTime createdAt;

  AnnouncementModel({
    required this.id,
    required this.classId,
    required this.title,
    required this.message,
    required this.postedBy,
    required this.postedByName,
    required this.createdAt,
  });

  factory AnnouncementModel.fromJson(Map<String, dynamic> json) {
    return AnnouncementModel(
      id: json['id'],
      classId: json['class_id'],
      title: json['title'],
      message: json['message'],
      postedBy: json['posted_by'],
      postedByName: json['posted_by_name'] ?? 'Lecturer', // Fallback if name not provided
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'class_id': classId,
      'title': title,
      'message': message,
      'posted_by': postedBy,
      'posted_by_name': postedByName,
      'created_at': createdAt.toIso8601String(),
    };
  }
} 