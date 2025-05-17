import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/user_model.dart' as app_models;
import '../models/class_model.dart';
import '../models/class_member_model.dart';

class SupabaseService {
  final SupabaseClient _client;

  SupabaseService(this._client);

  // Initialize Supabase
  static Future<SupabaseService> init({
    required String supabaseUrl,
    required String supabaseKey,
  }) async {
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseKey,
    );
    return SupabaseService(Supabase.instance.client);
  }

  // Sign up a new student
  Future<void> signUpStudent({
    required String email,
    required String password,
    required String fullName,
    required String studentNumber,
    required String institution,
    required String level,
  }) async {
    try {
      // Register user with Supabase Auth
      final authResponse = await _client.auth.signUp(
        email: email,
        password: password,
      );

      if (authResponse.user != null) {
        // Add student-specific data to profiles table
        await _client.from('profiles').insert({
          'id': authResponse.user!.id,
          'full_name': fullName,
          'email': email,
          'user_type': 'student',
          'student_number': studentNumber,
          'institution': institution,
          'level': level,
        });
      }
    } catch (e) {
      rethrow;
    }
  }

  // Sign up a new lecturer
  Future<void> signUpLecturer({
    required String email,
    required String password,
    required String fullName,
    required String staffId,
    required String department,
  }) async {
    try {
      // Register user with Supabase Auth
      final authResponse = await _client.auth.signUp(
        email: email,
        password: password,
      );

      if (authResponse.user != null) {
        // Add lecturer-specific data to profiles table
        await _client.from('profiles').insert({
          'id': authResponse.user!.id,
          'full_name': fullName,
          'email': email,
          'user_type': 'lecturer',
          'staff_id': staffId,
          'department': department,
        });
      }
    } catch (e) {
      rethrow;
    }
  }

  // Sign in an existing user
  Future<app_models.User?> signIn({
    required String email,
    required String password,
  }) async {
    try {
      // Authenticate with Supabase Auth
      final authResponse = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      // Fetch user profile data
      if (authResponse.user != null) {
        final userId = authResponse.user!.id;
        final userData = await _client
            .from('profiles')
            .select()
            .eq('id', userId)
            .single();

        // Create appropriate user object based on user_type
        if (userData['user_type'] == 'student') {
          return app_models.Student.fromJson(userData);
        } else if (userData['user_type'] == 'lecturer') {
          return app_models.Lecturer.fromJson(userData);
        }
      }
      return null;
    } catch (e) {
      rethrow;
    }
  }

  // Sign out the current user
  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  // Get current user
  Future<app_models.User?> getCurrentUser() async {
    final currentUser = _client.auth.currentUser;
    if (currentUser == null) return null;

    try {
      final userData = await _client
          .from('profiles')
          .select()
          .eq('id', currentUser.id)
          .single();

      if (userData['user_type'] == 'student') {
        return app_models.Student.fromJson(userData);
      } else if (userData['user_type'] == 'lecturer') {
        return app_models.Lecturer.fromJson(userData);
      }
      return null;
    } catch (e) {
      return null;
    }
  }
  
  // Create a new class (for lecturers)
  Future<ClassModel> createClass({
    required String name,
    required String courseCode,
    required String level,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      final currentUser = _client.auth.currentUser;
      if (currentUser == null) {
        throw Exception('User is not authenticated');
      }
      
      // Generate a unique class code
      final code = ClassModel.generateClassCode(courseCode);
      
      // Create a UUID for the class
      final uuid = Uuid();
      final classId = uuid.v4();
      
      // Create class record
      final classData = {
        'id': classId,
        'name': name,
        'code': code,
        'course_code': courseCode,
        'level': level,
        'start_date': startDate.toIso8601String(),
        'end_date': endDate.toIso8601String(),
        'created_by': currentUser.id,
        'created_at': DateTime.now().toIso8601String(),
      };
      
      await _client.from('classes').insert(classData);
      
      return ClassModel.fromJson(classData);
    } catch (e) {
      rethrow;
    }
  }
  
  // Get classes created by a lecturer
  Future<List<ClassModel>> getLecturerClasses() async {
    try {
      final currentUser = _client.auth.currentUser;
      if (currentUser == null) {
        throw Exception('User is not authenticated');
      }
      
      final response = await _client
          .from('classes')
          .select()
          .eq('created_by', currentUser.id)
          .order('created_at', ascending: false);
      
      return (response as List)
          .map((classData) => ClassModel.fromJson(classData))
          .toList();
    } catch (e) {
      rethrow;
    }
  }
  
  // Join a class (for students)
  Future<ClassModel> joinClass({required String classCode}) async {
    try {
      final currentUser = _client.auth.currentUser;
      if (currentUser == null) {
        throw Exception('User is not authenticated');
      }
      
      // Find the class with the given code
      final classResponse = await _client
          .from('classes')
          .select()
          .eq('code', classCode);
      
      // Check if any class was found with this code
      if ((classResponse as List).isEmpty) {
        throw Exception('Invalid class code. Please check and try again.');
      }
      
      final classData = classResponse.first;
      final classModel = ClassModel.fromJson(classData);
      
      // Check if the student is already a member of this class
      final existingMembership = await _client
          .from('class_members')
          .select()
          .eq('user_id', currentUser.id)
          .eq('class_id', classModel.id);
      
      if ((existingMembership as List).isNotEmpty) {
        throw Exception('You are already a member of this class');
      }
      
      // Create a UUID for the membership
      final uuid = Uuid();
      final membershipId = uuid.v4();
      
      // Add the student to the class
      await _client.from('class_members').insert({
        'id': membershipId,
        'user_id': currentUser.id,
        'class_id': classModel.id,
        'joined_at': DateTime.now().toIso8601String(),
      });
      
      return classModel;
    } catch (e) {
      // Handle Postgrest exceptions with user-friendly messages
      if (e is PostgrestException) {
        if (e.code == 'PGRST116') {
          throw Exception('Invalid class code. Please check and try again.');
        }
      }
      rethrow;
    }
  }
  
  // Get classes joined by a student
  Future<List<ClassModel>> getStudentClasses() async {
    try {
      final currentUser = _client.auth.currentUser;
      if (currentUser == null) {
        throw Exception('User is not authenticated');
      }
      
      // Get all class memberships for the current student
      final memberships = await _client
          .from('class_members')
          .select('class_id')
          .eq('user_id', currentUser.id);
      
      if ((memberships as List).isEmpty) {
        return [];
      }
      
      // Extract class IDs from memberships
      final classIds = memberships.map((m) => m['class_id']).toList();
      
      // Get all classes that the student is a member of
      final classes = await _client
          .from('classes')
          .select()
          .inFilter('id', classIds)
          .order('created_at', ascending: false);
      
      return (classes as List)
          .map((classData) => ClassModel.fromJson(classData))
          .toList();
    } catch (e) {
      rethrow;
    }
  }
  
  // Get the count of students in a class
  Future<int> getClassStudentsCount(String classId) async {
    try {
      final response = await _client
          .from('class_members')
          .select('id')
          .eq('class_id', classId);
      
      // Count the number of members
      return (response as List).length;
    } catch (e) {
      rethrow;
    }
  }

  // Leave a class (for students)
  Future<void> leaveClass(String classId) async {
    try {
      final currentUser = _client.auth.currentUser;
      if (currentUser == null) {
        throw Exception('User is not authenticated');
      }
      
      // Find the membership to delete
      final memberships = await _client
          .from('class_members')
          .select()
          .eq('user_id', currentUser.id)
          .eq('class_id', classId);
      
      if ((memberships as List).isEmpty) {
        throw Exception('You are not a member of this class');
      }
      
      // Get the membership ID
      final membershipId = memberships[0]['id'];
      
      // Delete the membership by its ID (more reliable than using a compound WHERE clause)
      final deleteResult = await _client
          .from('class_members')
          .delete()
          .eq('id', membershipId)
          .select();
      
      print("Delete membership result: $deleteResult");
      
      // Additional check to ensure deletion worked
      if ((deleteResult as List).isEmpty) {
        print("Warning: Delete operation didn't return data. This may indicate it failed silently.");
      }
      
    } catch (e) {
      print("Error leaving class: $e");
      rethrow;
    }
  }

  // Delete a class (for lecturers)
  Future<void> deleteClass(String classId) async {
    try {
      final currentUser = _client.auth.currentUser;
      if (currentUser == null) {
        throw Exception('User is not authenticated');
      }
      
      // First, verify that the user is the owner of the class
      final classData = await _client
          .from('classes')
          .select()
          .eq('id', classId)
          .limit(1);
      
      if (classData == null || (classData as List).isEmpty) {
        throw Exception('Class not found');
      }
      
      final classItem = classData[0];
      if (classItem['created_by'] != currentUser.id) {
        throw Exception('You do not have permission to delete this class');
      }
      
      // Delete memberships first (needed to handle foreign key constraints)
      final deleteMembers = await _client
          .from('class_members')
          .delete()
          .eq('class_id', classId);
      
      print("Deleted members response: $deleteMembers");
      
      // Then delete the class itself
      final deleteClass = await _client
          .from('classes')
          .delete()
          .eq('id', classId)
          .select();
      
      print("Deleted class response: $deleteClass");
      
      // If we got here without an exception, but there's no data in the response,
      // it might mean the row wasn't actually deleted
      if ((deleteClass as List).isEmpty) {
        print("Warning: Delete operation didn't return data. This may indicate it failed silently.");
      }
      
    } catch (e) {
      print("Error deleting class: $e");
      rethrow;
    }
  }
} 