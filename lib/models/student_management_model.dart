import 'package:intl/intl.dart';
import 'user_model.dart';

// Class to represent a student with class membership information
class ManagedStudentModel {
  final String id; // Student ID (user ID)
  final String fullName;
  final String email;
  final String studentNumber;
  final String institution;
  final String level;
  final String? phoneNumber;
  final String? profileImageUrl;
  final DateTime joinedAt;
  final String membershipId; // ID in class_members table

  ManagedStudentModel({
    required this.id,
    required this.fullName,
    required this.email,
    required this.studentNumber,
    required this.institution,
    required this.level,
    required this.joinedAt,
    required this.membershipId,
    this.phoneNumber,
    this.profileImageUrl,
  });

  factory ManagedStudentModel.fromJson(Map<String, dynamic> json) {
    return ManagedStudentModel(
      id: json['id'],
      fullName: json['full_name'],
      email: json['email'],
      studentNumber: json['student_number'],
      institution: json['institution'],
      level: json['level'],
      phoneNumber: json['phone_number'],
      profileImageUrl: json['profile_image_url'],
      joinedAt:
          json['joined_at'] != null
              ? DateTime.parse(json['joined_at'])
              : DateTime.now(),
      membershipId: json['membership_id'] ?? '',
    );
  }

  // Convert Student model to ManagedStudentModel
  factory ManagedStudentModel.fromStudent(
    Student student, {
    required DateTime joinedAt,
    required String membershipId,
  }) {
    return ManagedStudentModel(
      id: student.id,
      fullName: student.fullName,
      email: student.email,
      studentNumber: student.studentNumber,
      institution: student.institution,
      level: student.level,
      phoneNumber: student.phoneNumber,
      profileImageUrl: student.profileImageUrl,
      joinedAt: joinedAt,
      membershipId: membershipId,
    );
  }

  // Format joined date as a string
  String get joinedAtFormatted {
    final dateFormat = DateFormat('MMM d, yyyy');
    return dateFormat.format(joinedAt);
  }
}
