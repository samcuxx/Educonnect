import 'package:flutter/material.dart';
import '../models/class_model.dart';
import '../services/supabase_service.dart';

enum ClassProviderStatus { initial, loading, success, error }

class ClassProvider extends ChangeNotifier {
  final SupabaseService _supabaseService;

  ClassProviderStatus _status = ClassProviderStatus.initial;
  List<ClassModel> _classes = [];
  String? _errorMessage;

  ClassProvider(this._supabaseService);

  // Getters
  ClassProviderStatus get status => _status;
  List<ClassModel> get classes => _classes;
  String? get errorMessage => _errorMessage;

  // Get total student count for all lecturer classes
  int get totalStudents {
    int count = 0;
    for (var classItem in _classes) {
      count += classItem.studentCount;
    }
    return count;
  }

  // Load student counts for all classes
  Future<void> loadStudentCounts() async {
    try {
      for (int i = 0; i < _classes.length; i++) {
        final count = await _supabaseService.getClassStudentsCount(
          _classes[i].id,
        );
        _classes[i].studentCount = count;
      }
      notifyListeners();
    } catch (e) {
      // Handle error
      print('Error loading student counts: $e');
    }
  }

  // Create a new class (for lecturers)
  Future<void> createClass({
    required String name,
    required String courseCode,
    required String level,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      _status = ClassProviderStatus.loading;
      _errorMessage = null;
      notifyListeners();

      final createdClass = await _supabaseService.createClass(
        name: name,
        courseCode: courseCode,
        level: level,
        startDate: startDate,
        endDate: endDate,
      );

      _classes.insert(0, createdClass); // Add to the beginning of the list
      _status = ClassProviderStatus.success;
      notifyListeners();
    } catch (e) {
      _status = ClassProviderStatus.error;
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  // Update an existing class (for lecturers)
  Future<void> updateClass({
    required String classId,
    required String name,
    required String courseCode,
    required String level,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      _status = ClassProviderStatus.loading;
      _errorMessage = null;
      notifyListeners();

      final updatedClass = await _supabaseService.updateClass(
        classId: classId,
        name: name,
        courseCode: courseCode,
        level: level,
        startDate: startDate,
        endDate: endDate,
      );

      // Find and update the class in the list
      final index = _classes.indexWhere((c) => c.id == classId);
      if (index != -1) {
        _classes[index] = updatedClass;
      }

      _status = ClassProviderStatus.success;
      notifyListeners();
    } catch (e) {
      _status = ClassProviderStatus.error;
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  // Load lecturer's classes
  Future<void> loadLecturerClasses() async {
    try {
      _status = ClassProviderStatus.loading;
      _errorMessage = null;
      notifyListeners();

      final lecturerClasses = await _supabaseService.getLecturerClasses();
      _classes = lecturerClasses;
      _status = ClassProviderStatus.success;

      // Load student counts for each class
      await loadStudentCounts();

      notifyListeners();
    } catch (e) {
      _status = ClassProviderStatus.error;
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  // Join a class (for students)
  Future<void> joinClass({required String classCode}) async {
    try {
      _status = ClassProviderStatus.loading;
      _errorMessage = null;
      notifyListeners();

      final joinedClass = await _supabaseService.joinClass(
        classCode: classCode,
      );

      // Add joined class to the list if it doesn't exist already
      if (!_classes.any((c) => c.id == joinedClass.id)) {
        _classes.insert(0, joinedClass);
      }

      _status = ClassProviderStatus.success;
      notifyListeners();
    } catch (e) {
      _status = ClassProviderStatus.error;
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  // Load student's joined classes
  Future<void> loadStudentClasses() async {
    try {
      _status = ClassProviderStatus.loading;
      _errorMessage = null;
      notifyListeners();

      final studentClasses = await _supabaseService.getStudentClasses();
      _classes = studentClasses;
      _status = ClassProviderStatus.success;
      notifyListeners();
    } catch (e) {
      _status = ClassProviderStatus.error;
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  // Leave a class (for students)
  Future<void> leaveClass(String classId) async {
    try {
      _status = ClassProviderStatus.loading;
      _errorMessage = null;
      notifyListeners();

      await _supabaseService.leaveClass(classId);

      // Remove the class from the list
      _classes.removeWhere((c) => c.id == classId);

      _status = ClassProviderStatus.success;
      notifyListeners();
    } catch (e) {
      _status = ClassProviderStatus.error;
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  // Delete a class (for lecturers)
  Future<void> deleteClass(String classId) async {
    try {
      _status = ClassProviderStatus.loading;
      _errorMessage = null;
      notifyListeners();

      await _supabaseService.deleteClass(classId);

      // Remove the class from the list
      _classes.removeWhere((c) => c.id == classId);

      _status = ClassProviderStatus.success;
      notifyListeners();
    } catch (e) {
      _status = ClassProviderStatus.error;
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  // Reset state (e.g., when logging out)
  void reset() {
    _status = ClassProviderStatus.initial;
    _classes = [];
    _errorMessage = null;
    notifyListeners();
  }
}
