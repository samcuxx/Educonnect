// Base class for all users
abstract class User {
  final String id;
  final String fullName;
  final String email;
  final String userType; // 'student' or 'lecturer'

  User({
    required this.id,
    required this.fullName,
    required this.email,
    required this.userType,
  });
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
  }) : super(userType: 'student');

  factory Student.fromJson(Map<String, dynamic> json) {
    return Student(
      id: json['id'],
      fullName: json['full_name'],
      email: json['email'],
      studentNumber: json['student_number'],
      institution: json['institution'],
      level: json['level'],
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
  }) : super(userType: 'lecturer');

  factory Lecturer.fromJson(Map<String, dynamic> json) {
    return Lecturer(
      id: json['id'],
      fullName: json['full_name'],
      email: json['email'],
      staffId: json['staff_id'],
      department: json['department'],
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
    };
  }
} 