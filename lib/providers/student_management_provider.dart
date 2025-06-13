import 'package:flutter/material.dart';
import '../models/student_management_model.dart';
import '../services/supabase_service.dart';

enum StudentManagementStatus { initial, loading, success, error }

class StudentManagementProvider extends ChangeNotifier {
  final SupabaseService _supabaseService;

  StudentManagementStatus _status = StudentManagementStatus.initial;
  List<ManagedStudentModel> _students = [];
  String? _error;
  String? _selectedClassId;
  bool _isSearching = false;
  String _searchQuery = '';
  List<ManagedStudentModel> _filteredStudents = [];

  StudentManagementProvider(this._supabaseService);

  // Getters
  StudentManagementStatus get status => _status;
  List<ManagedStudentModel> get students =>
      _isSearching ? _filteredStudents : _students;
  String? get error => _error;
  String? get selectedClassId => _selectedClassId;
  bool get isSearching => _isSearching;
  String get searchQuery => _searchQuery;

  // Set the current class ID and load its students
  Future<void> setSelectedClass(String classId) async {
    if (_selectedClassId == classId && _students.isNotEmpty) {
      // Already loaded this class's students
      return;
    }

    _selectedClassId = classId;
    await loadStudentsForClass(classId);
  }

  // Load students for the selected class
  Future<void> loadStudentsForClass(String classId) async {
    try {
      _status = StudentManagementStatus.loading;
      _error = null;
      notifyListeners();

      final studentsData = await _supabaseService.getClassStudents(classId);

      _students =
          studentsData
              .map((data) => ManagedStudentModel.fromJson(data))
              .toList();

      // Sort students by name
      _students.sort((a, b) => a.fullName.compareTo(b.fullName));

      _status = StudentManagementStatus.success;
      notifyListeners();
    } catch (e) {
      _status = StudentManagementStatus.error;
      _error = e.toString();
      notifyListeners();
    }
  }

  // Remove a student from the class
  Future<void> removeStudentFromClass(String membershipId) async {
    try {
      _status = StudentManagementStatus.loading;
      notifyListeners();

      await _supabaseService.removeStudentFromClass(membershipId);

      // Remove the student from the local list
      _students.removeWhere((student) => student.membershipId == membershipId);

      // Update filtered list if searching
      if (_isSearching) {
        _filteredStudents = _filterStudents(_searchQuery);
      }

      _status = StudentManagementStatus.success;
      notifyListeners();
    } catch (e) {
      _status = StudentManagementStatus.error;
      _error = e.toString();
      notifyListeners();
    }
  }

  // Search students by name, email, or student number
  void searchStudents(String query) {
    _searchQuery = query.trim();
    _isSearching = _searchQuery.isNotEmpty;

    if (_isSearching) {
      _filteredStudents = _filterStudents(_searchQuery);
    }

    notifyListeners();
  }

  // Clear current search
  void clearSearch() {
    _searchQuery = '';
    _isSearching = false;
    _filteredStudents = [];
    notifyListeners();
  }

  // Helper method to filter students based on query
  List<ManagedStudentModel> _filterStudents(String query) {
    final lowercaseQuery = query.toLowerCase();

    return _students.where((student) {
      return student.fullName.toLowerCase().contains(lowercaseQuery) ||
          student.email.toLowerCase().contains(lowercaseQuery) ||
          student.studentNumber.toLowerCase().contains(lowercaseQuery);
    }).toList();
  }

  // Reset state (e.g., when changing class or logging out)
  void reset() {
    _status = StudentManagementStatus.initial;
    _students = [];
    _filteredStudents = [];
    _error = null;
    _selectedClassId = null;
    _isSearching = false;
    _searchQuery = '';
    notifyListeners();
  }
}
