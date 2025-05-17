import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/user_model.dart' as app_models;
import '../models/class_model.dart';
import '../models/class_member_model.dart';
import '../models/announcement_model.dart';
import '../models/resource_model.dart';
import 'package:path/path.dart' as path;

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

  // Create a new announcement
  Future<AnnouncementModel> createAnnouncement({
    required String classId,
    required String title,
    required String message,
  }) async {
    try {
      final currentUser = _client.auth.currentUser;
      if (currentUser == null) {
        throw Exception('User is not authenticated');
      }
      
      // Check if user is the creator of the class (only lecturers can post)
      final classData = await _client
          .from('classes')
          .select()
          .eq('id', classId)
          .eq('created_by', currentUser.id)
          .limit(1);
      
      if ((classData as List).isEmpty) {
        throw Exception('You do not have permission to post announcements in this class');
      }
      
      // Get lecturer name from profiles
      final profileData = await _client
          .from('profiles')
          .select('full_name')
          .eq('id', currentUser.id)
          .single();
      
      final lecturerName = profileData['full_name'] as String;
      
      // Generate UUID for the announcement
      final uuid = Uuid();
      final announcementId = uuid.v4();
      
      // Create announcement record - only include fields that exist in the database table
      final announcementData = {
        'id': announcementId,
        'class_id': classId,
        'title': title,
        'message': message,
        'posted_by': currentUser.id,
        'created_at': DateTime.now().toIso8601String(),
      };
      
      await _client.from('announcements').insert(announcementData);
      
      // Return the announcement model with the lecturer name included
      final completeData = {
        ...announcementData,
        'posted_by_name': lecturerName
      };
      
      return AnnouncementModel.fromJson(completeData);
    } catch (e) {
      rethrow;
    }
  }
  
  // Get announcements for a class
  Future<List<AnnouncementModel>> getClassAnnouncements(String classId) async {
    try {
      final currentUser = _client.auth.currentUser;
      if (currentUser == null) {
        throw Exception('User is not authenticated');
      }
      
      // Check if user has access to the class
      bool hasAccess = false;
      
      // Check if user is the lecturer
      final lecturerCheck = await _client
          .from('classes')
          .select()
          .eq('id', classId)
          .eq('created_by', currentUser.id);
      
      if ((lecturerCheck as List).isNotEmpty) {
        hasAccess = true;
      } else {
        // Check if user is a student in the class
        final studentCheck = await _client
            .from('class_members')
            .select()
            .eq('class_id', classId)
            .eq('user_id', currentUser.id);
        
        if ((studentCheck as List).isNotEmpty) {
          hasAccess = true;
        }
      }
      
      if (!hasAccess) {
        throw Exception('You do not have access to this class');
      }
      
      // Fetch announcements
      final announcements = await _client
          .from('announcements')
          .select()
          .eq('class_id', classId)
          .order('created_at', ascending: false);

      // Create a list to store the result
      final List<AnnouncementModel> result = [];
      
      // Process each announcement
      for (final announcement in announcements) {
        // Fetch the poster's profile information
        final posterProfile = await _client
            .from('profiles')
            .select('full_name')
            .eq('id', announcement['posted_by'])
            .single();
            
        // Create an announcement model with the profile data
        final announcementData = {...announcement};
        announcementData['posted_by_name'] = posterProfile['full_name'];
        
        result.add(AnnouncementModel.fromJson(announcementData));
      }
      
      return result;
    } catch (e) {
      rethrow;
    }
  }
  
  // Upload a resource file
  Future<ResourceModel> uploadResource({
    required String classId,
    required String title,
    required File file,
  }) async {
    try {
      final currentUser = _client.auth.currentUser;
      if (currentUser == null) {
        throw Exception('User is not authenticated');
      }
      
      // Check if user is the creator of the class (only lecturers can upload)
      final classData = await _client
          .from('classes')
          .select()
          .eq('id', classId)
          .eq('created_by', currentUser.id)
          .limit(1);
      
      if ((classData as List).isEmpty) {
        throw Exception('You do not have permission to upload resources to this class');
      }
      
      // Get lecturer name from profiles
      final profileData = await _client
          .from('profiles')
          .select('full_name')
          .eq('id', currentUser.id)
          .single();
      
      final lecturerName = profileData['full_name'] as String;
      
      // Generate UUID for the resource
      final uuid = Uuid();
      final resourceId = uuid.v4();
      
      // Process the file for upload
      final originalFileName = path.basename(file.path);
      final fileExtension = originalFileName.split('.').last.toLowerCase();
      final fileName = '${resourceId}_${DateTime.now().millisecondsSinceEpoch}.$fileExtension';
      final storagePath = 'resources/$classId/$fileName';
      
      print('Preparing to upload file: $originalFileName');
      print('Storage path: $storagePath');
      
      // Ensure the file exists and is readable
      if (!await file.exists()) {
        throw Exception('File does not exist: ${file.path}');
      }
      
      // Get file size for logging
      final fileSize = await file.length();
      print('File size: $fileSize bytes');
      
      // Read file as bytes for upload
      final fileBytes = await file.readAsBytes();
      
      try {
        // Upload file to Supabase Storage using bytes
        await _client.storage.from('educonnect').uploadBinary(
          storagePath,
          fileBytes,
          fileOptions: const FileOptions(
            cacheControl: '3600',
            upsert: true,
          ),
        );
        
        print('File uploaded successfully');
        
        // Get the public URL
        final fileUrl = _client.storage.from('educonnect').getPublicUrl(storagePath);
        print('File URL: $fileUrl');
        
        // Determine file type from extension for the model (but don't store in DB)
        String fileType = 'Other';
        switch(fileExtension.toLowerCase()) {
          case 'pdf': fileType = 'PDF'; break;
          case 'doc': case 'docx': fileType = 'Word'; break;
          case 'xls': case 'xlsx': fileType = 'Excel'; break;
          case 'ppt': case 'pptx': fileType = 'PowerPoint'; break;
          case 'jpg': case 'jpeg': case 'png': case 'gif': fileType = 'Image'; break;
          case 'txt': fileType = 'Text'; break;
        }
        
        // Create resource record - REMOVED file_type field that doesn't exist in the DB
        final resourceData = {
          'id': resourceId,
          'class_id': classId,
          'file_url': fileUrl,
          'title': title,
          'uploaded_by': currentUser.id,
          'created_at': DateTime.now().toIso8601String(),
        };
        
        // Insert the record into the resources table
        await _client.from('resources').insert(resourceData);
        
        // Return the resource model with the lecturer name included and file type for display
        final completeData = {
          ...resourceData,
          'uploaded_by_name': lecturerName,
          'file_type': fileType // Add this for the model but it's not in the DB
        };
        
        return ResourceModel.fromJson(completeData);
      } catch (storageError) {
        print('Storage error: $storageError');
        throw Exception('Failed to upload file: $storageError');
      }
    } catch (e) {
      print('Upload resource error: $e');
      rethrow;
    }
  }
  
  // Get resources for a class
  Future<List<ResourceModel>> getClassResources(String classId) async {
    try {
      final currentUser = _client.auth.currentUser;
      if (currentUser == null) {
        throw Exception('User is not authenticated');
      }
      
      // Check if user has access to the class
      bool hasAccess = false;
      
      // Check if user is the lecturer
      final lecturerCheck = await _client
          .from('classes')
          .select()
          .eq('id', classId)
          .eq('created_by', currentUser.id);
      
      if ((lecturerCheck as List).isNotEmpty) {
        hasAccess = true;
      } else {
        // Check if user is a student in the class
        final studentCheck = await _client
            .from('class_members')
            .select()
            .eq('class_id', classId)
            .eq('user_id', currentUser.id);
        
        if ((studentCheck as List).isNotEmpty) {
          hasAccess = true;
        }
      }
      
      if (!hasAccess) {
        throw Exception('You do not have access to this class');
      }
      
      // Fetch resources
      final resources = await _client
          .from('resources')
          .select()
          .eq('class_id', classId)
          .order('created_at', ascending: false);

      // Create a list to store the result
      final List<ResourceModel> result = [];
      
      // Process each resource
      for (final resource in resources) {
        // Fetch the uploader's profile information
        final uploaderProfile = await _client
            .from('profiles')
            .select('full_name')
            .eq('id', resource['uploaded_by'])
            .single();
            
        // Create a resource model with the profile data
        final resourceData = {...resource};
        resourceData['uploaded_by_name'] = uploaderProfile['full_name'];
        
        result.add(ResourceModel.fromJson(resourceData));
      }
      
      return result;
    } catch (e) {
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
      
      // Delete resources first
      await _client
          .from('resources')
          .delete()
          .eq('class_id', classId);
      
      // Delete announcements
      await _client
          .from('announcements')
          .delete()
          .eq('class_id', classId);
      
      // Delete memberships
      await _client
          .from('class_members')
          .delete()
          .eq('class_id', classId);
      
      // Then delete the class itself
      await _client
          .from('classes')
          .delete()
          .eq('id', classId);
    } catch (e) {
      rethrow;
    }
  }
} 