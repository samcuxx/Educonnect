class ClassMemberModel {
  final String id;
  final String userId;
  final String classId;
  final DateTime joinedAt;

  ClassMemberModel({
    required this.id,
    required this.userId,
    required this.classId,
    required this.joinedAt,
  });

  factory ClassMemberModel.fromJson(Map<String, dynamic> json) {
    return ClassMemberModel(
      id: json['id'],
      userId: json['user_id'],
      classId: json['class_id'],
      joinedAt: DateTime.parse(json['joined_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'class_id': classId,
      'joined_at': joinedAt.toIso8601String(),
    };
  }
} 