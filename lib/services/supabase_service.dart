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

  // Initialize Supabase
  static Future<SupabaseService> init({
    required String supabaseUrl,
    required String supabaseKey,
  }) async {
    await Supabase.initialize(url: supabaseUrl, anonKey: supabaseKey);
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

  // Get current user
  Future<app_models.User?> getCurrentUser() async {
    final currentUser = _client.auth.currentUser;
    if (currentUser == null) return null;

    try {
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
                phoneNumbers.add(phoneNumber);
                print('Adding phone number: $phoneNumber');
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

            // Create SMS message with both title and content
            final smsMessage =
                'New Announcement from $lecturerName for $courseCode - $className:\nTitle: $title\nMessage: $message';

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
          final classInfo = await _client
              .from('classes')
              .select('name, course_code')
              .eq('id', classId)
              .single();
          
          final className = classInfo['name'] as String;
          final courseCode = classInfo['course_code'] as String;
          
          // Format deadline for SMS
          final deadlineStr = "${deadline.day}/${deadline.month}/${deadline.year}";
          
          // Find all student members of the class
          final classMembers = await _client
              .from('class_members')
              .select('user_id')
              .eq('class_id', classId);
          
          if (classMembers.isNotEmpty) {
            // Get all student profiles with phone numbers
            final memberIds = (classMembers as List).map((m) => m['user_id']).toList();
            
            final studentProfiles = await _client
                .from('profiles')
                .select('phone_number')
                .inFilter('id', memberIds)
                .not('phone_number', 'is', null);
            
            print('Found ${studentProfiles.length} student profiles with phone numbers');
            
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
                final success = await _mnotifyService.sendSms(
                  recipient: phoneNumber,
                  message: smsMessage,
                );
                
                print('SMS to $phoneNumber success: $success');
              } catch (individualSmsError) {
                print('Error sending individual SMS to $phoneNumber: $individualSmsError');
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
