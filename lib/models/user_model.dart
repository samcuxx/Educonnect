// Base class for all users
abstract class User {
  final String id;
  final String fullName;
  final String email;
  final String userType; // 'student' or 'lecturer'
  final String? phoneNumber;
  final String? profileImageUrl;

  User({
    required this.id,
    required this.fullName,
    required this.email,
    required this.userType,
    this.phoneNumber,
    this.profileImageUrl,
  });
}

// Generic user model for chat system
class UserModel {
  final String id;
  final String fullName;
  final String email;
  final String role; // 'student' or 'lecturer'
  final String phoneNumber;
  final String? profileImageUrl;

  UserModel({
    required this.id,
    required this.fullName,
    required this.email,
    required this.role,
    required this.phoneNumber,
    this.profileImageUrl,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] ?? '',
      fullName: json['full_name'] ?? '',
      email: json['email'] ?? '',
      role: json['user_type'] ?? json['role'] ?? '',
      phoneNumber: json['phone_number'] ?? '',
      profileImageUrl: json['profile_image_url'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'full_name': fullName,
      'email': email,
      'role': role,
      'phone_number': phoneNumber,
      'profile_image_url': profileImageUrl,
    };
  }
}

// Student-specific user model
class Student extends User {
  final String studentNumber;
  final String institution;
  final String level;

  Student({
    required super.id,
    required super.fullName,
    required super.email,
    required this.studentNumber,
    required this.institution,
    required this.level,
    super.phoneNumber,
    super.profileImageUrl,
  }) : super(userType: 'student');

  factory Student.fromJson(Map<String, dynamic> json) {
    return Student(
      id: json['id'],
      fullName: json['full_name'],
      email: json['email'],
      studentNumber: json['student_number'],
      institution: json['institution'],
      level: json['level'],
      phoneNumber: json['phone_number'],
      profileImageUrl: json['profile_image_url'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'full_name': fullName,
      'email': email,
      'user_type': userType,
      'student_number': studentNumber,
      'institution': institution,
      'level': level,
      'phone_number': phoneNumber,
      'profile_image_url': profileImageUrl,
    };
  }
}

// Lecturer-specific user model
class Lecturer extends User {
  final String staffId;
  final String department;

  Lecturer({
    required super.id,
    required super.fullName,
    required super.email,
    required this.staffId,
    required this.department,
    super.phoneNumber,
    super.profileImageUrl,
  }) : super(userType: 'lecturer');

  factory Lecturer.fromJson(Map<String, dynamic> json) {
    return Lecturer(
      id: json['id'],
      fullName: json['full_name'],
      email: json['email'],
      staffId: json['staff_id'],
      department: json['department'],
      phoneNumber: json['phone_number'],
      profileImageUrl: json['profile_image_url'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'full_name': fullName,
      'email': email,
      'user_type': userType,
      'staff_id': staffId,
      'department': department,
      'phone_number': phoneNumber,
      'profile_image_url': profileImageUrl,
    };
  }
}
