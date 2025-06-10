import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/user_model.dart' as app_models;
import '../models/class_model.dart';
import '../models/class_member_model.dart';
import '../models/announcement_model.dart';
import '../models/resource_model.dart';
import '../models/assignment_model.dart';
import '../models/submission_model.dart';
import 'package:path/path.dart' as path;
import '../utils/app_config.dart';
import 'mnotify_service.dart';

class SupabaseService {
  final SupabaseClient _client;
  late MNotifyService _mnotifyService;

  SupabaseService(this._client) {
    // Initialize MNotify service with API key from config
    _mnotifyService = MNotifyService(apiKey: AppConfig.mNotifyApiKey);
  }

  // Get MNotify service instance for OTP operations
  MNotifyService get mnotifyService => _mnotifyService;

  // Initialize Supabase
  static Future<SupabaseService> init({
    required String supabaseUrl,
    required String supabaseKey,
  }) async {
    await Supabase.initialize(url: supabaseUrl, anonKey: supabaseKey);
    return SupabaseService(Supabase.instance.client);
  }

  // Helper method to send welcome SMS to new users
  Future<void> _sendWelcomeSms({
    required String fullName,
    required String userType,
    String? phoneNumber,
  }) async {
    if (phoneNumber == null ||
        phoneNumber.isEmpty ||
        !AppConfig.enableSmsNotifications) {
      return;
    }

    try {
      // Standardize format - ensure it starts with + or country code
      String formattedNumber = phoneNumber.trim().replaceAll(' ', '');
      if (!formattedNumber.startsWith('+') &&
          !formattedNumber.startsWith('233')) {
        // Add Ghana country code if not present (assuming Ghana numbers)
        if (formattedNumber.startsWith('0')) {
          formattedNumber = '233${formattedNumber.substring(1)}';
        } else {
          formattedNumber = '233$formattedNumber';
        }
      }

      // Create a simple, professional welcome message
      final welcomeMessage =
          'Welcome to EduConnect, $fullName! Your ${userType.toLowerCase()} account has been created successfully. Use the app to connect, learn, and share educational resources.';

      print('Sending welcome SMS to new $userType: $formattedNumber');

      // Send the welcome SMS with retry logic
      bool success = false;
      int attempts = 0;

      while (!success && attempts < 2) {
        attempts++;
        success = await _mnotifyService.sendSms(
          recipient: formattedNumber,
          message: welcomeMessage,
        );

        if (success) {
          print('Welcome SMS sent successfully to $formattedNumber');
          break;
        } else if (attempts < 2) {
          // Wait briefly before retry
          await Future.delayed(const Duration(seconds: 1));
        }
      }

      if (!success) {
        print('Failed to send welcome SMS after multiple attempts');
      }
    } catch (e) {
      print('Error sending welcome SMS: $e');
      // Don't throw the error - we don't want signup to fail if SMS fails
    }
  }

  // Check if email already exists in the database
  Future<bool> isEmailExists(String email) async {
    try {
      final response = await _client
          .from('profiles')
          .select('id')
          .eq('email', email.toLowerCase().trim())
          .limit(1);

      return (response as List).isNotEmpty;
    } catch (e) {
      print('Error checking email existence: $e');
      return false; // Assume email doesn't exist on error to allow process to continue
    }
  }

  // Check if phone number already exists in the database
  Future<bool> isPhoneNumberExists(String phoneNumber) async {
    try {
      final formattedNumber = phoneNumber.replaceAll(' ', '');
      final response = await _client
          .from('profiles')
          .select('id')
          .eq('phone_number', formattedNumber)
          .limit(1);

      return (response as List).isNotEmpty;
    } catch (e) {
      print('Error checking phone number existence: $e');
      return false; // Assume phone doesn't exist on error to allow process to continue
    }
  }

  // Get user phone number by email for password reset
  Future<String?> getUserPhoneByEmail(String email) async {
    try {
      final response = await _client
          .from('profiles')
          .select('phone_number')
          .eq('email', email.toLowerCase().trim())
          .limit(1);

      if ((response as List).isNotEmpty) {
        final phoneNumber = response.first['phone_number'] as String?;
        if (phoneNumber != null && phoneNumber.isNotEmpty) {
          return phoneNumber;
        }
      }
      return null;
    } catch (e) {
      print('Error getting user phone by email: $e');
      return null;
    }
  }

  // Reset user password using database function
  Future<bool> resetUserPassword({
    required String email,
    required String newPassword,
  }) async {
    try {
      // First, verify the user exists in our profiles table
      final profileResponse = await _client
          .from('profiles')
          .select('id')
          .eq('email', email.toLowerCase().trim())
          .limit(1);

      if ((profileResponse as List).isEmpty) {
        print('User not found with email: $email');
        return false;
      }

      final userId = profileResponse.first['id'] as String;

      // Use a database function to update the password
      // This function needs to be created in your Supabase database
      try {
        final result = await _client.rpc(
          'reset_user_password',
          params: {'user_id': userId, 'new_password': newPassword},
        );

        print('Password reset successful for user: $email');
        return true;
      } catch (rpcError) {
        print('Database function error: $rpcError');

        // If the function doesn't exist, provide clear instructions
        if (rpcError.toString().toLowerCase().contains('function') &&
            (rpcError.toString().toLowerCase().contains('does not exist') ||
                rpcError.toString().toLowerCase().contains('not found'))) {
          print('\n=== DATABASE FUNCTION REQUIRED ===');
          print(
            'The "reset_user_password" function is not found in your Supabase database.',
          );
          print('Please execute this SQL in your Supabase SQL editor:\n');
          print('''
CREATE OR REPLACE FUNCTION reset_user_password(user_id UUID, new_password TEXT)
RETURNS BOOLEAN 
LANGUAGE plpgsql 
SECURITY DEFINER
AS \$\$
BEGIN
  UPDATE auth.users 
  SET 
    encrypted_password = crypt(new_password, gen_salt('bf')),
    updated_at = NOW()
  WHERE id = user_id;
  
  RETURN FOUND;
END;
\$\$;
          ''');
          print('=== END DATABASE FUNCTION ===\n');
        }

        throw Exception('Database function required. Check console for SQL.');
      }
    } catch (e) {
      print('Error resetting user password: $e');
      return false;
    }
  }

  // Sign up a new student
  Future<void> signUpStudent({
    required String email,
    required String password,
    required String fullName,
    required String studentNumber,
    required String institution,
    required String level,
    String? phoneNumber,
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
          'phone_number': phoneNumber,
        });

        // Send welcome SMS if phone number is provided
        await _sendWelcomeSms(
          fullName: fullName,
          userType: 'Student',
          phoneNumber: phoneNumber,
        );
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
    String? phoneNumber,
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
          'phone_number': phoneNumber,
        });

        // Send welcome SMS if phone number is provided
        await _sendWelcomeSms(
          fullName: fullName,
          userType: 'Lecturer',
          phoneNumber: phoneNumber,
        );
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
        final userData =
            await _client.from('profiles').select().eq('id', userId).single();

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

  // Get current user with improved session persistence
  Future<app_models.User?> getCurrentUser() async {
    try {
      // First check if we have a valid session
      final session = await _client.auth.currentSession;

      // If no valid session exists, try to recover it
      if (session == null || session.isExpired) {
        // Try to refresh the session
        final response = await _client.auth.refreshSession();

        // If we still don't have a valid session, user is not authenticated
        if (response.session == null) {
          return null;
        }
      }

      // Get the current user after confirming session
      final currentUser = _client.auth.currentUser;
      if (currentUser == null) return null;

      // Fetch user profile data
      final userData =
          await _client
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
      print('Error recovering user session: $e');
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
      final deleteResult =
          await _client
              .from('class_members')
              .delete()
              .eq('id', membershipId)
              .select();

      print("Delete membership result: $deleteResult");

      // Additional check to ensure deletion worked
      if ((deleteResult as List).isEmpty) {
        print(
          "Warning: Delete operation didn't return data. This may indicate it failed silently.",
        );
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
    bool sendSms = true,
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
        throw Exception(
          'You do not have permission to post announcements in this class',
        );
      }

      // Get lecturer name from profiles
      final profileData =
          await _client
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

      // Send SMS to all students in the class if sendSms is true and globally enabled
      if (sendSms && AppConfig.enableSmsNotifications) {
        try {
          // Get class info for SMS
          final classInfo =
              await _client
                  .from('classes')
                  .select('name, course_code')
                  .eq('id', classId)
                  .single();

          final className = classInfo['name'] as String;
          final courseCode = classInfo['course_code'] as String;

          // Find all student members of the class
          final classMembers = await _client
              .from('class_members')
              .select('user_id')
              .eq('class_id', classId);

          if (classMembers.isNotEmpty) {
            // Get all student profiles with phone numbers
            final memberIds =
                (classMembers as List).map((m) => m['user_id']).toList();

            final studentProfiles = await _client
                .from('profiles')
                .select('phone_number')
                .inFilter('id', memberIds)
                .not('phone_number', 'is', null);

            print(
              'Found ${studentProfiles.length} student profiles with phone numbers',
            );

            // Extract phone numbers
            final List<String> phoneNumbers = [];
            for (final profile in studentProfiles) {
              final phoneNumber = profile['phone_number'] as String?;
              if (phoneNumber != null && phoneNumber.isNotEmpty) {
                // Standardize format - ensure it starts with + or country code
                String formattedNumber = phoneNumber.trim().replaceAll(' ', '');
                if (!formattedNumber.startsWith('+') &&
                    !formattedNumber.startsWith('233')) {
                  // Add Ghana country code if not present (assuming Ghana numbers)
                  if (formattedNumber.startsWith('0')) {
                    formattedNumber = '233${formattedNumber.substring(1)}';
                  } else {
                    formattedNumber = '233$formattedNumber';
                  }
                }
                phoneNumbers.add(formattedNumber);
                print('Adding phone number: $formattedNumber');
              }
            }

            if (phoneNumbers.isEmpty) {
              print('No valid phone numbers found for students in this class');
              return AnnouncementModel.fromJson({
                ...announcementData,
                'posted_by_name': lecturerName,
              });
            }

            print('Sending SMS to ${phoneNumbers.length} phone numbers');

            // Create SMS message with appropriate length handling for better delivery
            final baseMessage =
                'New Announcement from $lecturerName for $courseCode - $className:\nTitle: $title';

            // Check total length including the message
            final fullMessageLength =
                baseMessage.length + '\nMessage: '.length + message.length;

            // If total message exceeds safe SMS length (280 chars), don't include content
            final smsMessage =
                fullMessageLength > 280
                    ? '$baseMessage\nCheck app for full message content'
                    : '$baseMessage\nMessage: $message';

            print('SMS Message: $smsMessage');

            // Send SMS to each student individually for better delivery rate
            for (final phoneNumber in phoneNumbers) {
              try {
                // Try up to 2 times for announcements to ensure delivery
                bool success = false;
                int attempts = 0;

                while (!success && attempts < 2) {
                  attempts++;
                  print('SMS attempt $attempts to $phoneNumber');

                  success = await _mnotifyService.sendSms(
                    recipient: phoneNumber,
                    message: smsMessage,
                  );

                  if (success) {
                    print(
                      'SMS to $phoneNumber success after $attempts attempt(s)',
                    );
                    break;
                  } else if (attempts < 2) {
                    // Wait briefly before retry
                    await Future.delayed(const Duration(seconds: 1));
                  }
                }

                if (!success) {
                  print(
                    'Failed to send SMS to $phoneNumber after multiple attempts',
                  );
                }
              } catch (individualSmsError) {
                print(
                  'Error sending individual SMS to $phoneNumber: $individualSmsError',
                );
              }
            }
          } else {
            print('No class members found for this class');
          }
        } catch (smsError) {
          // Log error but don't fail the announcement creation
          print('Error sending SMS notifications: $smsError');
        }
      }

      // Return the announcement model with the lecturer name included
      final completeData = {
        ...announcementData,
        'posted_by_name': lecturerName,
      };

      return AnnouncementModel.fromJson(completeData);
    } catch (e) {
      print('Error creating announcement: $e');
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
        final posterProfile =
            await _client
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

  // Delete an announcement
  Future<void> deleteAnnouncement(String announcementId, String classId) async {
    try {
      final currentUser = _client.auth.currentUser;
      if (currentUser == null) {
        throw Exception('User is not authenticated');
      }

      // Check if user is the creator of the class (only lecturers can delete)
      final classData = await _client
          .from('classes')
          .select()
          .eq('id', classId)
          .eq('created_by', currentUser.id)
          .limit(1);

      if ((classData as List).isEmpty) {
        throw Exception(
          'You do not have permission to delete announcements in this class',
        );
      }

      // Delete the announcement
      final deleteResult =
          await _client
              .from('announcements')
              .delete()
              .eq('id', announcementId)
              .select();

      if ((deleteResult as List).isEmpty) {
        throw Exception(
          'Failed to delete announcement or announcement not found',
        );
      }

      print('Announcement deleted successfully: $announcementId');
    } catch (e) {
      print('Error deleting announcement: $e');
      rethrow;
    }
  }

  // Delete a resource
  Future<void> deleteResource(String resourceId, String classId) async {
    try {
      final currentUser = _client.auth.currentUser;
      if (currentUser == null) {
        throw Exception('User is not authenticated');
      }

      // Check if user is the creator of the class (only lecturers can delete)
      final classData = await _client
          .from('classes')
          .select()
          .eq('id', classId)
          .eq('created_by', currentUser.id)
          .limit(1);

      if ((classData as List).isEmpty) {
        throw Exception(
          'You do not have permission to delete resources in this class',
        );
      }

      // Get the resource info before deletion to remove file from storage
      final resourceData =
          await _client
              .from('resources')
              .select('file_url')
              .eq('id', resourceId)
              .single();

      final fileUrl = resourceData['file_url'] as String;

      // Delete the resource record
      final deleteResult =
          await _client
              .from('resources')
              .delete()
              .eq('id', resourceId)
              .select();

      if ((deleteResult as List).isEmpty) {
        throw Exception('Failed to delete resource or resource not found');
      }

      // Try to delete the file from storage
      try {
        final uri = Uri.parse(fileUrl);
        final path = uri.path;
        final storagePath =
            path.startsWith('/storage/v1/object/public/educonnect/')
                ? path.substring('/storage/v1/object/public/educonnect/'.length)
                : path;

        await _client.storage.from('educonnect').remove([storagePath]);
        print('File removed from storage: $storagePath');
      } catch (storageError) {
        print('Warning: Could not remove file from storage: $storageError');
        // Don't fail the deletion if storage removal fails
      }

      print('Resource deleted successfully: $resourceId');
    } catch (e) {
      print('Error deleting resource: $e');
      rethrow;
    }
  }

  // Delete an assignment
  Future<void> deleteAssignment(String assignmentId, String classId) async {
    try {
      final currentUser = _client.auth.currentUser;
      if (currentUser == null) {
        throw Exception('User is not authenticated');
      }

      // Check if user is the creator of the class (only lecturers can delete)
      final classData = await _client
          .from('classes')
          .select()
          .eq('id', classId)
          .eq('created_by', currentUser.id)
          .limit(1);

      if ((classData as List).isEmpty) {
        throw Exception(
          'You do not have permission to delete assignments in this class',
        );
      }

      // Get the assignment info before deletion to remove file from storage if exists
      final assignmentData =
          await _client
              .from('assignments')
              .select('file_url')
              .eq('id', assignmentId)
              .single();

      final fileUrl = assignmentData['file_url'] as String?;

      // Delete any related submissions first
      await _client
          .from('submissions')
          .delete()
          .eq('assignment_id', assignmentId);

      // Delete the assignment record
      final deleteResult =
          await _client
              .from('assignments')
              .delete()
              .eq('id', assignmentId)
              .select();

      if ((deleteResult as List).isEmpty) {
        throw Exception('Failed to delete assignment or assignment not found');
      }

      // Try to delete the file from storage if it exists
      if (fileUrl != null && fileUrl.isNotEmpty) {
        try {
          final uri = Uri.parse(fileUrl);
          final path = uri.path;
          final storagePath =
              path.startsWith('/storage/v1/object/public/educonnect/')
                  ? path.substring(
                    '/storage/v1/object/public/educonnect/'.length,
                  )
                  : path;

          await _client.storage.from('educonnect').remove([storagePath]);
          print('Assignment file removed from storage: $storagePath');
        } catch (storageError) {
          print(
            'Warning: Could not remove assignment file from storage: $storageError',
          );
          // Don't fail the deletion if storage removal fails
        }
      }

      print('Assignment deleted successfully: $assignmentId');
    } catch (e) {
      print('Error deleting assignment: $e');
      rethrow;
    }
  }

  // Upload a resource file
  Future<ResourceModel> uploadResource({
    required String classId,
    required String title,
    required File file,
    bool sendSms = true,
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
        throw Exception(
          'You do not have permission to upload resources to this class',
        );
      }

      // Get lecturer name from profiles
      final profileData =
          await _client
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
      final fileName =
          '${resourceId}_${DateTime.now().millisecondsSinceEpoch}.$fileExtension';
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
        await _client.storage
            .from('educonnect')
            .uploadBinary(
              storagePath,
              fileBytes,
              fileOptions: const FileOptions(
                cacheControl: '3600',
                upsert: true,
              ),
            );

        print('File uploaded successfully');

        // Get the public URL
        final fileUrl = _client.storage
            .from('educonnect')
            .getPublicUrl(storagePath);
        print('File URL: $fileUrl');

        // Determine file type from extension for the model (but don't store in DB)
        String fileType = 'Other';
        switch (fileExtension.toLowerCase()) {
          case 'pdf':
            fileType = 'PDF';
            break;
          case 'doc':
          case 'docx':
            fileType = 'Word';
            break;
          case 'xls':
          case 'xlsx':
            fileType = 'Excel';
            break;
          case 'ppt':
          case 'pptx':
            fileType = 'PowerPoint';
            break;
          case 'jpg':
          case 'jpeg':
          case 'png':
          case 'gif':
            fileType = 'Image';
            break;
          case 'txt':
            fileType = 'Text';
            break;
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
          'file_type':
              fileType, // Add this for the model but it's not in the DB
        };

        // Send SMS notification to students if enabled
        if (sendSms && AppConfig.enableSmsNotifications) {
          try {
            // Get class info for SMS
            final classInfo =
                await _client
                    .from('classes')
                    .select('name, course_code')
                    .eq('id', classId)
                    .single();

            final className = classInfo['name'] as String;
            final courseCode = classInfo['course_code'] as String;

            // Find all student members of the class
            final classMembers = await _client
                .from('class_members')
                .select('user_id')
                .eq('class_id', classId);

            if (classMembers.isNotEmpty) {
              // Get all student profiles with phone numbers
              final memberIds =
                  (classMembers as List).map((m) => m['user_id']).toList();

              final studentProfiles = await _client
                  .from('profiles')
                  .select('phone_number')
                  .inFilter('id', memberIds)
                  .not('phone_number', 'is', null);

              print(
                'Found ${studentProfiles.length} student profiles with phone numbers',
              );

              // Extract phone numbers
              final List<String> phoneNumbers = [];
              for (final profile in studentProfiles) {
                final phoneNumber = profile['phone_number'] as String?;
                if (phoneNumber != null && phoneNumber.isNotEmpty) {
                  phoneNumbers.add(phoneNumber);
                  print('Adding phone number: $phoneNumber');
                }
              }

              if (phoneNumbers.isEmpty) {
                print(
                  'No valid phone numbers found for students in this class',
                );
                return ResourceModel.fromJson(completeData);
              }

              print('Sending SMS to ${phoneNumbers.length} phone numbers');

              // Create SMS message
              final smsMessage =
                  'New Resource from $lecturerName for $courseCode - $className:\n'
                  'Resource: $title\n'
                  'Type: $fileType\n'
                  'Check your app to download';

              print('SMS Message: $smsMessage');

              // Send SMS to each student individually for better delivery rate
              for (final phoneNumber in phoneNumbers) {
                try {
                  final success = await _mnotifyService.sendSms(
                    recipient: phoneNumber,
                    message: smsMessage,
                  );

                  print('SMS to $phoneNumber success: $success');
                } catch (individualSmsError) {
                  print(
                    'Error sending individual SMS to $phoneNumber: $individualSmsError',
                  );
                }
              }
            }
          } catch (smsError) {
            // Log error but don't fail the resource upload
            print('Error sending SMS notifications for resource: $smsError');
          }
        }

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
        final uploaderProfile =
            await _client
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
      await _client.from('resources').delete().eq('class_id', classId);

      // Delete announcements
      await _client.from('announcements').delete().eq('class_id', classId);

      // Delete memberships
      await _client.from('class_members').delete().eq('class_id', classId);

      // Then delete the class itself
      await _client.from('classes').delete().eq('id', classId);
    } catch (e) {
      rethrow;
    }
  }

  // Update an existing class (for lecturers)
  Future<ClassModel> updateClass({
    required String classId,
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

      // First, verify that the user is the owner of the class
      final classData = await _client
          .from('classes')
          .select()
          .eq('id', classId)
          .eq('created_by', currentUser.id)
          .limit(1);

      if (classData == null || (classData as List).isEmpty) {
        throw Exception(
          'Class not found or you do not have permission to edit it',
        );
      }

      // Prepare the updated data
      final updates = {
        'name': name,
        'course_code': courseCode,
        'level': level,
        'start_date': startDate.toIso8601String(),
        'end_date': endDate.toIso8601String(),
      };

      // Update the class in the database
      final updatedClass =
          await _client
              .from('classes')
              .update(updates)
              .eq('id', classId)
              .select()
              .single();

      return ClassModel.fromJson(updatedClass);
    } catch (e) {
      rethrow;
    }
  }

  // Create a new assignment
  Future<AssignmentModel> createAssignment({
    required String classId,
    required String title,
    required String? description,
    required DateTime deadline,
    File? file,
    bool sendSms = true,
  }) async {
    try {
      final currentUser = _client.auth.currentUser;
      if (currentUser == null) {
        throw Exception('User is not authenticated');
      }

      // Check if user is the creator of the class (only lecturers can create assignments)
      final classData = await _client
          .from('classes')
          .select()
          .eq('id', classId)
          .eq('created_by', currentUser.id)
          .limit(1);

      if ((classData as List).isEmpty) {
        throw Exception(
          'You do not have permission to create assignments in this class',
        );
      }

      // Get lecturer name from profiles
      final profileData =
          await _client
              .from('profiles')
              .select('full_name')
              .eq('id', currentUser.id)
              .single();

      final lecturerName = profileData['full_name'] as String;

      // Generate UUID for the assignment
      final uuid = Uuid();
      final assignmentId = uuid.v4();

      String? fileUrl;
      String fileType = 'None';

      // Process file upload if provided
      if (file != null) {
        // Process the file for upload
        final originalFileName = path.basename(file.path);
        final fileExtension = originalFileName.split('.').last.toLowerCase();
        final fileName =
            '${assignmentId}_${DateTime.now().millisecondsSinceEpoch}.$fileExtension';
        final storagePath = 'assignments/$classId/$fileName';

        print('Preparing to upload assignment file: $originalFileName');
        print('Storage path: $storagePath');

        // Ensure the file exists and is readable
        if (!await file.exists()) {
          throw Exception('File does not exist: ${file.path}');
        }

        // Read file as bytes for upload
        final fileBytes = await file.readAsBytes();

        // Upload file to Supabase Storage
        await _client.storage
            .from('educonnect')
            .uploadBinary(
              storagePath,
              fileBytes,
              fileOptions: const FileOptions(
                cacheControl: '3600',
                upsert: true,
              ),
            );

        // Get the public URL
        fileUrl = _client.storage.from('educonnect').getPublicUrl(storagePath);

        // Determine file type from extension
        switch (fileExtension.toLowerCase()) {
          case 'pdf':
            fileType = 'PDF';
            break;
          case 'doc':
          case 'docx':
            fileType = 'Word';
            break;
          case 'xls':
          case 'xlsx':
            fileType = 'Excel';
            break;
          case 'ppt':
          case 'pptx':
            fileType = 'PowerPoint';
            break;
          case 'jpg':
          case 'jpeg':
          case 'png':
          case 'gif':
            fileType = 'Image';
            break;
          case 'txt':
            fileType = 'Text';
            break;
        }
      }

      // Create assignment record
      final assignmentData = {
        'id': assignmentId,
        'class_id': classId,
        'title': title,
        'description': description,
        'file_url': fileUrl,
        'assigned_by': currentUser.id,
        'created_at': DateTime.now().toIso8601String(),
        'deadline': deadline.toIso8601String(),
      };

      // Insert the record into the assignments table
      await _client.from('assignments').insert(assignmentData);

      // Return the assignment model with the lecturer name included
      final completeData = {
        ...assignmentData,
        'assigned_by_name': lecturerName,
        'file_type': fileType,
      };

      // Send SMS notification to students if enabled
      if (sendSms && AppConfig.enableSmsNotifications) {
        try {
          // Get class info for SMS
          final classInfo =
              await _client
                  .from('classes')
                  .select('name, course_code')
                  .eq('id', classId)
                  .single();

          final className = classInfo['name'] as String;
          final courseCode = classInfo['course_code'] as String;

          // Format deadline for SMS
          final deadlineStr =
              "${deadline.day}/${deadline.month}/${deadline.year}";

          // Find all student members of the class
          final classMembers = await _client
              .from('class_members')
              .select('user_id')
              .eq('class_id', classId);

          if (classMembers.isNotEmpty) {
            // Get all student profiles with phone numbers
            final memberIds =
                (classMembers as List).map((m) => m['user_id']).toList();

            final studentProfiles = await _client
                .from('profiles')
                .select('phone_number')
                .inFilter('id', memberIds)
                .not('phone_number', 'is', null);

            print(
              'Found ${studentProfiles.length} student profiles with phone numbers',
            );

            // Extract phone numbers
            final List<String> phoneNumbers = [];
            for (final profile in studentProfiles) {
              final phoneNumber = profile['phone_number'] as String?;
              if (phoneNumber != null && phoneNumber.isNotEmpty) {
                phoneNumbers.add(phoneNumber);
                print('Adding phone number: $phoneNumber');
              }
            }

            if (phoneNumbers.isEmpty) {
              print('No valid phone numbers found for students in this class');
              return AssignmentModel.fromJson(completeData);
            }

            print('Sending SMS to ${phoneNumbers.length} phone numbers');

            // Create SMS message
            final smsMessage =
                'New Assignment from $lecturerName for $courseCode - $className:\n'
                'Title: $title\n'
                'Due date: $deadlineStr\n'
                'Check the app for details';

            print('SMS Message: $smsMessage');

            // Send SMS to each student individually for better delivery rate
            for (final phoneNumber in phoneNumbers) {
              try {
                // Try up to 2 times for announcements to ensure delivery
                bool success = false;
                int attempts = 0;

                while (!success && attempts < 2) {
                  attempts++;
                  print('SMS attempt $attempts to $phoneNumber');

                  success = await _mnotifyService.sendSms(
                    recipient: phoneNumber,
                    message: smsMessage,
                  );

                  if (success) {
                    print(
                      'SMS to $phoneNumber success after $attempts attempt(s)',
                    );
                    break;
                  } else if (attempts < 2) {
                    // Wait briefly before retry
                    await Future.delayed(const Duration(seconds: 1));
                  }
                }

                if (!success) {
                  print(
                    'Failed to send SMS to $phoneNumber after multiple attempts',
                  );
                }
              } catch (individualSmsError) {
                print(
                  'Error sending individual SMS to $phoneNumber: $individualSmsError',
                );
              }
            }
          }
        } catch (smsError) {
          // Log error but don't fail the assignment creation
          print('Error sending SMS notifications for assignment: $smsError');
        }
      }

      return AssignmentModel.fromJson(completeData);
    } catch (e) {
      print('Create assignment error: $e');
      rethrow;
    }
  }

  // Get assignments for a class
  Future<List<AssignmentModel>> getClassAssignments(String classId) async {
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

      // Fetch assignments
      final assignments = await _client
          .from('assignments')
          .select()
          .eq('class_id', classId)
          .order('created_at', ascending: false);

      // Create a list to store the result
      final List<AssignmentModel> result = [];

      // Process each assignment
      for (final assignment in assignments) {
        // Fetch the assigner's profile information
        final assignerProfile =
            await _client
                .from('profiles')
                .select('full_name')
                .eq('id', assignment['assigned_by'])
                .single();

        // Create an assignment model with the profile data
        final assignmentData = {...assignment};
        assignmentData['assigned_by_name'] = assignerProfile['full_name'];

        // Determine file type
        if (assignment['file_url'] != null) {
          final fileUrl = assignment['file_url'] as String;
          final fileExtension = fileUrl.split('.').last.toLowerCase();
          String fileType = 'Document';

          switch (fileExtension.toLowerCase()) {
            case 'pdf':
              fileType = 'PDF';
              break;
            case 'doc':
            case 'docx':
              fileType = 'Word';
              break;
            case 'xls':
            case 'xlsx':
              fileType = 'Excel';
              break;
            case 'ppt':
            case 'pptx':
              fileType = 'PowerPoint';
              break;
            case 'jpg':
            case 'jpeg':
            case 'png':
            case 'gif':
              fileType = 'Image';
              break;
            case 'txt':
              fileType = 'Text';
              break;
          }

          assignmentData['file_type'] = fileType;
        } else {
          assignmentData['file_type'] = 'None';
        }

        result.add(AssignmentModel.fromJson(assignmentData));
      }

      return result;
    } catch (e) {
      rethrow;
    }
  }

  // Submit an assignment (for students)
  Future<SubmissionModel> submitAssignment({
    required String assignmentId,
    required File file,
  }) async {
    try {
      final currentUser = _client.auth.currentUser;
      if (currentUser == null) {
        throw Exception('User is not authenticated');
      }

      // Get assignment details to verify class membership
      final assignmentData =
          await _client
              .from('assignments')
              .select()
              .eq('id', assignmentId)
              .single();

      final classId = assignmentData['class_id'] as String;

      // Check if user is a student in the class
      final studentCheck = await _client
          .from('class_members')
          .select()
          .eq('class_id', classId)
          .eq('user_id', currentUser.id);

      if ((studentCheck as List).isEmpty) {
        throw Exception('You are not a member of this class');
      }

      // Check if student has already submitted
      final existingSubmission = await _client
          .from('submissions')
          .select()
          .eq('assignment_id', assignmentId)
          .eq('student_id', currentUser.id);

      // Generate UUID for the submission
      final uuid = Uuid();
      final submissionId =
          existingSubmission.isNotEmpty
              ? existingSubmission[0]['id']
              : uuid.v4();

      // Get student name and number from profiles
      final profileData =
          await _client
              .from('profiles')
              .select('full_name, student_number')
              .eq('id', currentUser.id)
              .single();

      final studentName = profileData['full_name'] as String;
      final studentNumber = profileData['student_number'] as String?;

      // Process the file for upload
      final originalFileName = path.basename(file.path);
      final fileExtension = originalFileName.split('.').last.toLowerCase();
      final fileName =
          '${submissionId}_${DateTime.now().millisecondsSinceEpoch}.$fileExtension';
      final storagePath = 'submissions/$assignmentId/$fileName';

      // Read file as bytes for upload
      final fileBytes = await file.readAsBytes();

      // Upload file to Supabase Storage
      await _client.storage
          .from('educonnect')
          .uploadBinary(
            storagePath,
            fileBytes,
            fileOptions: const FileOptions(cacheControl: '3600', upsert: true),
          );

      // Get the public URL
      final fileUrl = _client.storage
          .from('educonnect')
          .getPublicUrl(storagePath);

      // Determine file type
      String fileType = 'Document';
      switch (fileExtension.toLowerCase()) {
        case 'pdf':
          fileType = 'PDF';
          break;
        case 'doc':
        case 'docx':
          fileType = 'Word';
          break;
        case 'xls':
        case 'xlsx':
          fileType = 'Excel';
          break;
        case 'ppt':
        case 'pptx':
          fileType = 'PowerPoint';
          break;
        case 'jpg':
        case 'jpeg':
        case 'png':
        case 'gif':
          fileType = 'Image';
          break;
        case 'txt':
          fileType = 'Text';
          break;
      }

      // Create submission record
      final submissionData = {
        'id': submissionId,
        'assignment_id': assignmentId,
        'student_id': currentUser.id,
        'file_url': fileUrl,
        'submitted_at': DateTime.now().toIso8601String(),
      };

      // Insert or update the submission
      if (existingSubmission.isEmpty) {
        await _client.from('submissions').insert(submissionData);
      } else {
        await _client
            .from('submissions')
            .update({
              'file_url': fileUrl,
              'submitted_at': DateTime.now().toIso8601String(),
            })
            .eq('id', submissionId);
      }

      // Return the submission model
      final completeData = {
        ...submissionData,
        'student_name': studentName,
        'student_number': studentNumber,
        'file_type': fileType,
      };

      return SubmissionModel.fromJson(completeData);
    } catch (e) {
      print('Submit assignment error: $e');
      rethrow;
    }
  }

  // Check if a student has submitted an assignment
  Future<bool> hasSubmittedAssignment(String assignmentId) async {
    try {
      final currentUser = _client.auth.currentUser;
      if (currentUser == null) {
        throw Exception('User is not authenticated');
      }

      // Check for existing submission
      final submission = await _client
          .from('submissions')
          .select()
          .eq('assignment_id', assignmentId)
          .eq('student_id', currentUser.id);

      return submission.isNotEmpty;
    } catch (e) {
      rethrow;
    }
  }

  // Get submissions for an assignment (for lecturers)
  Future<List<SubmissionModel>> getAssignmentSubmissions(
    String assignmentId,
  ) async {
    try {
      final currentUser = _client.auth.currentUser;
      if (currentUser == null) {
        throw Exception('User is not authenticated');
      }

      // Get assignment details
      final assignmentData =
          await _client
              .from('assignments')
              .select()
              .eq('id', assignmentId)
              .single();

      final classId = assignmentData['class_id'] as String;
      final assignedBy = assignmentData['assigned_by'] as String;

      // Verify the current user is the lecturer for this class
      if (currentUser.id != assignedBy) {
        throw Exception('You do not have permission to view these submissions');
      }

      // Fetch submissions
      final submissions = await _client
          .from('submissions')
          .select()
          .eq('assignment_id', assignmentId)
          .order('submitted_at', ascending: false);

      // Create a list to store the result
      final List<SubmissionModel> result = [];

      // Process each submission
      for (final submission in submissions) {
        // Fetch the student's profile information
        final studentProfile =
            await _client
                .from('profiles')
                .select('full_name, student_number')
                .eq('id', submission['student_id'])
                .single();

        // Create a submission model with the profile data
        final submissionData = {...submission};
        submissionData['student_name'] = studentProfile['full_name'];
        submissionData['student_number'] = studentProfile['student_number'];

        // Determine file type
        if (submission['file_url'] != null) {
          final fileUrl = submission['file_url'] as String;
          final fileExtension = fileUrl.split('.').last.toLowerCase();
          String fileType = 'Document';

          switch (fileExtension.toLowerCase()) {
            case 'pdf':
              fileType = 'PDF';
              break;
            case 'doc':
            case 'docx':
              fileType = 'Word';
              break;
            case 'xls':
            case 'xlsx':
              fileType = 'Excel';
              break;
            case 'ppt':
            case 'pptx':
              fileType = 'PowerPoint';
              break;
            case 'jpg':
            case 'jpeg':
            case 'png':
            case 'gif':
              fileType = 'Image';
              break;
            case 'txt':
              fileType = 'Text';
              break;
          }

          submissionData['file_type'] = fileType;
        } else {
          submissionData['file_type'] = 'None';
        }

        result.add(SubmissionModel.fromJson(submissionData));
      }

      return result;
    } catch (e) {
      rethrow;
    }
  }

  // Update student profile
  Future<app_models.Student> updateStudentProfile({
    required String userId,
    required String fullName,
    required String studentNumber,
    required String institution,
    required String level,
    String? phoneNumber,
  }) async {
    try {
      final updatedData =
          await _client
              .from('profiles')
              .update({
                'full_name': fullName,
                'student_number': studentNumber,
                'institution': institution,
                'level': level,
                if (phoneNumber != null) 'phone_number': phoneNumber,
              })
              .eq('id', userId)
              .select()
              .single();

      return app_models.Student.fromJson(updatedData);
    } catch (e) {
      rethrow;
    }
  }

  // Update lecturer profile
  Future<app_models.Lecturer> updateLecturerProfile({
    required String userId,
    required String fullName,
    required String staffId,
    required String department,
    String? phoneNumber,
  }) async {
    try {
      final updatedData =
          await _client
              .from('profiles')
              .update({
                'full_name': fullName,
                'staff_id': staffId,
                'department': department,
                if (phoneNumber != null) 'phone_number': phoneNumber,
              })
              .eq('id', userId)
              .select()
              .single();

      return app_models.Lecturer.fromJson(updatedData);
    } catch (e) {
      rethrow;
    }
  }
}
