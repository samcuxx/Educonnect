import 'package:uuid/uuid.dart';

class ClassModel {
  final String id;
  final String name;
  final String code;
  final String courseCode;
  final String level;
  final DateTime startDate;
  final DateTime endDate;
  final String createdBy;
  final DateTime createdAt;
  int studentCount = 0; // Default student count

  ClassModel({
    required this.id,
    required this.name,
    required this.code,
    required this.courseCode,
    required this.level,
    required this.startDate,
    required this.endDate,
    required this.createdBy,
    required this.createdAt,
    this.studentCount = 0, // Default parameter
  });

  // Generate a unique class code based on the course code
  static String generateClassCode(String courseCode) {
    final uuid = Uuid();
    final randomString = uuid.v4().substring(0, 4).toUpperCase();
    return '${courseCode.toUpperCase()}-$randomString';
  }

  factory ClassModel.fromJson(Map<String, dynamic> json) {
    return ClassModel(
      id: json['id'],
      name: json['name'],
      code: json['code'],
      courseCode: json['course_code'],
      level: json['level'],
      startDate: DateTime.parse(json['start_date']),
      endDate: DateTime.parse(json['end_date']),
      createdBy: json['created_by'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'code': code,
      'course_code': courseCode,
      'level': level,
      'start_date': startDate.toIso8601String(),
      'end_date': endDate.toIso8601String(),
      'created_by': createdBy,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
