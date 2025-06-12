import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/class_model.dart';
import '../services/supabase_service.dart';
import '../services/cache_manager.dart';

enum ClassProviderStatus { initial, loading, success, error, loaded }

class ClassProvider extends ChangeNotifier {
  final SupabaseService _supabaseService;
  final CacheManager _cacheManager = CacheManager();

  ClassProviderStatus _status = ClassProviderStatus.initial;
  List<ClassModel> _classes = [];
  String? _error;
  bool _isOffline = false;

  ClassProvider(this._supabaseService) {
    // Load cached student count immediately
    _loadCachedStudentCount();

    // Listen to connectivity changes
    _cacheManager.connectivityStream.listen((isOnline) {
      final wasOffline = _isOffline;
      _isOffline = !isOnline;

      // If we just came back online and had loaded classes before, refresh data
      if (wasOffline && isOnline && _classes.isNotEmpty) {
        _refreshClassesBasedOnRole();
      }

      // If we just went offline, make sure we have cached data loaded
      if (!wasOffline && !isOnline && _classes.isEmpty) {
        _loadCachedClasses();
      }

      notifyListeners();
    });
  }

  // Getters
  ClassProviderStatus get status => _status;
  List<ClassModel> get classes => _classes;
  String? get error => _error;
  String? get errorMessage => _error;
  bool get isOffline => _isOffline;
  CacheManager get cacheManager => _cacheManager;

  // Get total student count for all lecturer classes
  int _cachedStudentCount = 0;

  int get totalStudents {
    // Calculate from classes if we have them with student counts
    int calculatedCount = 0;
    for (var classItem in _classes) {
      calculatedCount += classItem.studentCount;
    }

    // If we have a calculated count, use it (and update cache)
    if (calculatedCount > 0) {
      // Update cached count if it's different
      if (_cachedStudentCount != calculatedCount) {
        _cachedStudentCount = calculatedCount;
        // Save to persistent storage (don't await to avoid blocking)
        _saveCachedStudentCount();
      }
      return calculatedCount;
    }

    // Otherwise use cached count
    return _cachedStudentCount;
  }

  // Helper method to refresh classes based on current role
  // Load cached student count from SharedPreferences
  Future<void> _loadCachedStudentCount() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _cachedStudentCount = prefs.getInt('cached_student_count') ?? 0;
      notifyListeners(); // Notify listeners when cached count is loaded
    } catch (e) {
      print('Error loading cached student count: $e');
    }
  }

  Future<void> _refreshClassesBasedOnRole() async {
    // Load cached student count
    await _loadCachedStudentCount();
    // This is determined elsewhere and not easily accessible here
    // For simplicity, we'll try both methods
    try {
      await loadLecturerClasses();
    } catch (e) {
      try {
        await loadStudentClasses();
      } catch (e) {
        // If both fail, we're probably not authenticated
        // Do nothing
      }
    }
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
      _error = null;
      notifyListeners();

      // Check if we're online
      if (!_cacheManager.isOnline) {
        throw Exception(
          'Cannot create class while offline. Please check your internet connection and try again.',
        );
      }

      final createdClass = await _supabaseService.createClass(
        name: name,
        courseCode: courseCode,
        level: level,
        startDate: startDate,
        endDate: endDate,
      );

      _classes.insert(0, createdClass); // Add to the beginning of the list

      // Update cached classes
      await _cacheManager.getClasses(
        onlineDataFetcher: () async => _classes,
        forceRefresh: true,
      );

      _status = ClassProviderStatus.success;
      notifyListeners();
    } catch (e) {
      _status = ClassProviderStatus.error;
      _error = e.toString();
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
      _error = null;
      notifyListeners();

      // Check if we're online
      if (!_cacheManager.isOnline) {
        throw Exception(
          'Cannot update class while offline. Please check your internet connection and try again.',
        );
      }

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

      // Update cached classes
      await _cacheManager.getClasses(
        onlineDataFetcher: () async => _classes,
        forceRefresh: true,
      );

      _status = ClassProviderStatus.success;
      notifyListeners();
    } catch (e) {
      _status = ClassProviderStatus.error;
      _error = e.toString();
      notifyListeners();
    }
  }

  // Load lecturer classes with caching
  Future<void> loadLecturerClasses() async {
    try {
      _status = ClassProviderStatus.loading;

      // Load cached student count first
      await _loadCachedStudentCount();

      // Load from cache first
      final cachedClasses = await _cacheManager.getCachedClasses();

      if (cachedClasses.isNotEmpty) {
        _classes = cachedClasses;
        _status = ClassProviderStatus.loaded;
        notifyListeners();
      }

      // Only fetch from network if online
      if (_cacheManager.isOnline) {
        _classes = await _cacheManager.getClasses(
          onlineDataFetcher:
              () async => await _supabaseService.getLecturerClasses(),
          forceRefresh: false,
        );

        // Load student counts if online
        await loadStudentCounts();

        // Save updated student count
        await _saveCachedStudentCount();

        _status = ClassProviderStatus.loaded;
        notifyListeners();
      }
    } catch (e) {
      print('Error loading lecturer classes: $e');
      _status = ClassProviderStatus.error;
      _error = e.toString();
      notifyListeners();
    }
  }

  // Load student classes with caching
  Future<void> loadStudentClasses() async {
    try {
      _status = ClassProviderStatus.loading;

      // Load from cache first
      final cachedClasses = await _cacheManager.getCachedClasses();

      if (cachedClasses.isNotEmpty) {
        _classes = cachedClasses;
        _status = ClassProviderStatus.loaded;
        notifyListeners();
      }

      // Only fetch from network if online
      if (_cacheManager.isOnline) {
        _classes = await _cacheManager.getClasses(
          onlineDataFetcher:
              () async => await _supabaseService.getStudentClasses(),
          forceRefresh: false,
        );

        _status = ClassProviderStatus.loaded;
        notifyListeners();
      }
    } catch (e) {
      print('Error loading student classes: $e');
      _status = ClassProviderStatus.error;
      _error = e.toString();
      notifyListeners();
    }
  }

  // Join a class (for students)
  Future<void> joinClass({required String classCode}) async {
    try {
      _status = ClassProviderStatus.loading;
      _error = null;
      notifyListeners();

      // Check if we're online
      if (!_cacheManager.isOnline) {
        throw Exception(
          'Cannot join class while offline. Please check your internet connection and try again.',
        );
      }

      final joinedClass = await _supabaseService.joinClass(
        classCode: classCode,
      );

      _classes.insert(0, joinedClass); // Add to the beginning of the list

      // Update cached classes
      await _cacheManager.getClasses(
        onlineDataFetcher: () async => _classes,
        forceRefresh: true,
      );

      _status = ClassProviderStatus.success;
      notifyListeners();
    } catch (e) {
      _status = ClassProviderStatus.error;
      _error = e.toString();
      notifyListeners();
    }
  }

  // Leave a class (for students)
  Future<void> leaveClass(String classId) async {
    try {
      _status = ClassProviderStatus.loading;
      _error = null;
      notifyListeners();

      // Check if we're online
      if (!_cacheManager.isOnline) {
        throw Exception(
          'Cannot leave class while offline. Please check your internet connection and try again.',
        );
      }

      await _supabaseService.leaveClass(classId);

      // Remove the class from the list
      _classes.removeWhere((c) => c.id == classId);

      // Update cached classes
      await _cacheManager.getClasses(
        onlineDataFetcher: () async => _classes,
        forceRefresh: true,
      );

      _status = ClassProviderStatus.success;
      notifyListeners();
    } catch (e) {
      _status = ClassProviderStatus.error;
      _error = e.toString();
      notifyListeners();
    }
  }

  // Delete a class (for lecturers)
  Future<void> deleteClass(String classId) async {
    try {
      _status = ClassProviderStatus.loading;
      _error = null;
      notifyListeners();

      // Check if we're online
      if (!_cacheManager.isOnline) {
        throw Exception(
          'Cannot delete class while offline. Please check your internet connection and try again.',
        );
      }

      await _supabaseService.deleteClass(classId);

      // Remove the class from the list
      _classes.removeWhere((c) => c.id == classId);

      // Update cached classes
      await _cacheManager.getClasses(
        onlineDataFetcher: () async => _classes,
        forceRefresh: true,
      );

      _status = ClassProviderStatus.success;
      notifyListeners();
    } catch (e) {
      _status = ClassProviderStatus.error;
      _error = e.toString();
      notifyListeners();
    }
  }

  // Save student count to cache
  Future<void> _saveCachedStudentCount() async {
    try {
      int count = 0;
      for (var classItem in _classes) {
        count += classItem.studentCount;
      }

      if (count > 0) {
        _cachedStudentCount = count;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt('cached_student_count', _cachedStudentCount);
      }
    } catch (e) {
      print('Error saving cached student count: $e');
    }
  }

  Future<void> refreshClasses({
    required bool isLecturer,
    bool showLoadingIndicator = true,
  }) async {
    try {
      if (showLoadingIndicator) {
        _status = ClassProviderStatus.loading;
        notifyListeners();
      }

      if (isLecturer) {
        _classes = await _cacheManager.getClasses(
          onlineDataFetcher:
              () async => await _supabaseService.getLecturerClasses(),
          forceRefresh: true,
        );

        // Load student counts if online
        if (_cacheManager.isOnline) {
          await loadStudentCounts();

          // Save student count for offline access
          await _saveCachedStudentCount();
        }
      } else {
        _classes = await _cacheManager.getClasses(
          onlineDataFetcher:
              () async => await _supabaseService.getStudentClasses(),
          forceRefresh: true,
        );
      }

      _status = ClassProviderStatus.success;
      notifyListeners();
    } catch (e) {
      _status = ClassProviderStatus.error;
      _error = e.toString();
      notifyListeners();
    }
  }

  // Reset state (e.g., when logging out)
  void reset() {
    _status = ClassProviderStatus.initial;
    _classes = [];
    _error = null;
    notifyListeners();
  }

  // Set offline status
  void setOfflineStatus(bool offline) {
    _isOffline = offline;
    notifyListeners();
  }

  // Load cached classes when going offline
  Future<void> _loadCachedClasses() async {
    try {
      // Load cached student count
      await _loadCachedStudentCount();

      // Load cached classes
      final cachedClasses = await _cacheManager.getCachedClasses();

      if (cachedClasses.isNotEmpty) {
        _classes = cachedClasses;
        _status = ClassProviderStatus.loaded;
        notifyListeners();
      }
    } catch (e) {
      print('Error loading cached classes: $e');
    }
  }
}
