import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_model.dart' as app_models;

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
} 