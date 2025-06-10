import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/class_model.dart';
import '../models/resource_model.dart';
import '../models/assignment_model.dart';
import '../models/user_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocalStorageService {
  // Singleton instance
  static final LocalStorageService _instance = LocalStorageService._internal();
  factory LocalStorageService() => _instance;
  LocalStorageService._internal();

  // Box names
  static const String _userBox = 'userBox';
  static const String _classesBox = 'classesBox';
  static const String _resourcesBox = 'resourcesBox';
  static const String _assignmentsBox = 'assignmentsBox';
  static const String _settingsBox = 'settingsBox';

  // Initialize Hive
  Future<void> initialize() async {
    await Hive.initFlutter();
    await Hive.openBox(_userBox);
    await Hive.openBox(_classesBox);
    await Hive.openBox(_resourcesBox);
    await Hive.openBox(_assignmentsBox);
    await Hive.openBox(_settingsBox);
  }

  // User methods
  Future<void> saveUser(User user) async {
    final box = Hive.box(_userBox);

    Map<String, dynamic> userMap;

    if (user is Student) {
      userMap = user.toJson();
    } else if (user is Lecturer) {
      userMap = user.toJson();
    } else {
      // Fallback for base User class (shouldn't happen in practice)
      userMap = {
        'id': user.id,
        'full_name': user.fullName,
        'email': user.email,
        'user_type': user.userType,
        'phone_number': user.phoneNumber,
      };
    }

    await box.put('currentUser', jsonEncode(userMap));
  }

  User? getUser() {
    final box = Hive.box(_userBox);
    final userJson = box.get('currentUser');
    if (userJson == null) return null;

    final userMap = jsonDecode(userJson) as Map<String, dynamic>;

    // Create the appropriate user type based on user_type
    if (userMap['user_type'] == 'student') {
      return Student.fromJson(userMap);
    } else if (userMap['user_type'] == 'lecturer') {
      return Lecturer.fromJson(userMap);
    }

    // Should not reach here in practice
    return null;
  }

  Future<void> clearUser() async {
    final box = Hive.box(_userBox);
    await box.delete('currentUser');
  }

  // Classes methods
  Future<void> saveClasses(List<ClassModel> classes) async {
    final box = Hive.box(_classesBox);
    final classesList = classes.map((e) => jsonEncode(e.toJson())).toList();
    await box.put('classes', classesList);

    // Save last update timestamp
    await box.put('lastUpdated', DateTime.now().toIso8601String());
  }

  List<ClassModel> getClasses() {
    final box = Hive.box(_classesBox);
    final classesList = box.get('classes', defaultValue: <String>[]) as List;
    return classesList
        .cast<String>()
        .map((e) => ClassModel.fromJson(jsonDecode(e)))
        .toList();
  }

  DateTime? getClassesLastUpdated() {
    final box = Hive.box(_classesBox);
    final lastUpdated = box.get('lastUpdated');
    if (lastUpdated == null) return null;
    return DateTime.parse(lastUpdated);
  }

  // Resources methods
  Future<void> saveResources(List<ResourceModel> resources) async {
    final box = Hive.box(_resourcesBox);
    final resourcesList = resources.map((e) => jsonEncode(e.toJson())).toList();
    await box.put('resources', resourcesList);

    // Save last update timestamp
    await box.put('lastUpdated', DateTime.now().toIso8601String());
  }

  List<ResourceModel> getResources() {
    final box = Hive.box(_resourcesBox);
    final resourcesList =
        box.get('resources', defaultValue: <String>[]) as List;
    return resourcesList
        .cast<String>()
        .map((e) => ResourceModel.fromJson(jsonDecode(e)))
        .toList();
  }

  DateTime? getResourcesLastUpdated() {
    final box = Hive.box(_resourcesBox);
    final lastUpdated = box.get('lastUpdated');
    if (lastUpdated == null) return null;
    return DateTime.parse(lastUpdated);
  }

  // Resources by class
  Future<void> saveResourcesByClass(
    String classId,
    List<ResourceModel> resources,
  ) async {
    final box = Hive.box(_resourcesBox);
    final resourcesList = resources.map((e) => jsonEncode(e.toJson())).toList();
    await box.put('resources_$classId', resourcesList);

    // Save last update timestamp
    await box.put('lastUpdated_$classId', DateTime.now().toIso8601String());
  }

  List<ResourceModel> getResourcesByClass(String classId) {
    final box = Hive.box(_resourcesBox);
    final resourcesList =
        box.get('resources_$classId', defaultValue: <String>[]) as List;
    return resourcesList
        .cast<String>()
        .map((e) => ResourceModel.fromJson(jsonDecode(e)))
        .toList();
  }

  // Assignments methods
  Future<void> saveAssignments(List<AssignmentModel> assignments) async {
    final box = Hive.box(_assignmentsBox);
    final assignmentsList =
        assignments.map((e) => jsonEncode(e.toJson())).toList();
    await box.put('assignments', assignmentsList);

    // Save last update timestamp
    await box.put('lastUpdated', DateTime.now().toIso8601String());
  }

  List<AssignmentModel> getAssignments() {
    final box = Hive.box(_assignmentsBox);
    final assignmentsList =
        box.get('assignments', defaultValue: <String>[]) as List;
    return assignmentsList
        .cast<String>()
        .map((e) => AssignmentModel.fromJson(jsonDecode(e)))
        .toList();
  }

  DateTime? getAssignmentsLastUpdated() {
    final box = Hive.box(_assignmentsBox);
    final lastUpdated = box.get('lastUpdated');
    if (lastUpdated == null) return null;
    return DateTime.parse(lastUpdated);
  }

  // Assignments by class
  Future<void> saveAssignmentsByClass(
    String classId,
    List<AssignmentModel> assignments,
  ) async {
    final box = Hive.box(_assignmentsBox);
    final assignmentsList =
        assignments.map((e) => jsonEncode(e.toJson())).toList();
    await box.put('assignments_$classId', assignmentsList);

    // Save last update timestamp
    await box.put('lastUpdated_$classId', DateTime.now().toIso8601String());
  }

  List<AssignmentModel> getAssignmentsByClass(String classId) {
    final box = Hive.box(_assignmentsBox);
    final assignmentsList =
        box.get('assignments_$classId', defaultValue: <String>[]) as List;
    return assignmentsList
        .cast<String>()
        .map((e) => AssignmentModel.fromJson(jsonDecode(e)))
        .toList();
  }

  // Settings methods
  Future<void> saveSetting(String key, dynamic value) async {
    final box = Hive.box(_settingsBox);
    await box.put(key, value);
  }

  dynamic getSetting(String key, {dynamic defaultValue}) {
    final box = Hive.box(_settingsBox);
    return box.get(key, defaultValue: defaultValue);
  }

  // Clear all data
  Future<void> clearAll() async {
    await Hive.box(_userBox).clear();
    await Hive.box(_classesBox).clear();
    await Hive.box(_resourcesBox).clear();
    await Hive.box(_assignmentsBox).clear();
    await Hive.box(_settingsBox).clear();

    // Also clear SharedPreferences data
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    print('All local cache cleared');
  }
}
