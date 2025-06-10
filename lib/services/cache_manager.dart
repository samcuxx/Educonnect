import 'dart:async';
import 'package:educonnect/services/connectivity_service.dart';
import 'package:educonnect/services/local_storage_service.dart';
import '../providers/auth_provider.dart';
import '../models/class_model.dart';
import '../models/resource_model.dart';
import '../models/assignment_model.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';

class CacheManager {
  // Singleton instance
  static final CacheManager _instance = CacheManager._internal();
  factory CacheManager() => _instance;
  CacheManager._internal();

  // Services
  final LocalStorageService _localStorage = LocalStorageService();
  final ConnectivityService _connectivity = ConnectivityService();

  // Cache settings
  static const Duration _cacheValidity = Duration(hours: 24);

  // Initialize
  Future<void> initialize() async {
    try {
      // We'll initialize the services more safely
      await Hive.initFlutter();

      // Connect to connectivity service
      _connectivity.initialize();

      print('CacheManager initialized successfully');
    } catch (e) {
      print('Error initializing CacheManager: $e');
    }
  }

  // Check if data needs refresh
  bool _needsRefresh(DateTime? lastUpdated) {
    if (lastUpdated == null) return true;
    final now = DateTime.now();
    return now.difference(lastUpdated) > _cacheValidity;
  }

  // Classes methods
  Future<List<ClassModel>> getClasses({
    required Future<List<ClassModel>> Function() onlineDataFetcher,
    bool forceRefresh = false,
  }) async {
    // First check local cache
    final cachedClasses = _localStorage.getClasses();
    final lastUpdated = _localStorage.getClassesLastUpdated();

    // Return cached data if:
    // 1. We're offline AND we have cached data, OR
    // 2. We're online, not forcing refresh, cache is valid, and we have cached data
    if ((!_connectivity.isConnected && cachedClasses.isNotEmpty) ||
        (_connectivity.isConnected &&
            !forceRefresh &&
            !_needsRefresh(lastUpdated) &&
            cachedClasses.isNotEmpty)) {
      return cachedClasses;
    }

    // If we're offline and don't have cached data, return empty list
    if (!_connectivity.isConnected) {
      return cachedClasses; // Return empty list or whatever is cached
    }

    // Otherwise fetch from online
    try {
      final onlineClasses = await onlineDataFetcher();

      // Cache the fetched data
      await _localStorage.saveClasses(onlineClasses);

      return onlineClasses;
    } catch (e) {
      // If fetch fails and we have cached data, return that
      if (cachedClasses.isNotEmpty) {
        return cachedClasses;
      }
      // Otherwise, rethrow to let caller handle the error
      rethrow;
    }
  }

  // Resources methods
  Future<List<ResourceModel>> getResources({
    required Future<List<ResourceModel>> Function() onlineDataFetcher,
    bool forceRefresh = false,
  }) async {
    // First check local cache
    final cachedResources = _localStorage.getResources();
    final lastUpdated = _localStorage.getResourcesLastUpdated();

    // Return cached data if:
    // 1. We're offline AND we have cached data, OR
    // 2. We're online, not forcing refresh, cache is valid, and we have cached data
    if ((!_connectivity.isConnected && cachedResources.isNotEmpty) ||
        (_connectivity.isConnected &&
            !forceRefresh &&
            !_needsRefresh(lastUpdated) &&
            cachedResources.isNotEmpty)) {
      return cachedResources;
    }

    // If we're offline and don't have cached data, return empty list
    if (!_connectivity.isConnected) {
      return cachedResources; // Return empty list or whatever is cached
    }

    // Otherwise fetch from online
    try {
      final onlineResources = await onlineDataFetcher();

      // Cache the fetched data
      await _localStorage.saveResources(onlineResources);

      return onlineResources;
    } catch (e) {
      // If fetch fails and we have cached data, return that
      if (cachedResources.isNotEmpty) {
        return cachedResources;
      }
      // Otherwise, rethrow to let caller handle the error
      rethrow;
    }
  }

  // Resources by class
  Future<List<ResourceModel>> getResourcesByClass({
    required String classId,
    required Future<List<ResourceModel>> Function() onlineDataFetcher,
    bool forceRefresh = false,
  }) async {
    // First check local cache
    final cachedResources = _localStorage.getResourcesByClass(classId);
    final lastUpdated = _localStorage.getResourcesLastUpdated();

    // Return cached data if:
    // 1. We're offline AND we have cached data, OR
    // 2. We're online, not forcing refresh, cache is valid, and we have cached data
    if ((!_connectivity.isConnected && cachedResources.isNotEmpty) ||
        (_connectivity.isConnected &&
            !forceRefresh &&
            !_needsRefresh(lastUpdated) &&
            cachedResources.isNotEmpty)) {
      return cachedResources;
    }

    // If we're offline and don't have cached data, return empty list
    if (!_connectivity.isConnected) {
      return cachedResources; // Return empty list or whatever is cached
    }

    // Otherwise fetch from online
    try {
      final onlineResources = await onlineDataFetcher();

      // Cache the fetched data
      await _localStorage.saveResourcesByClass(classId, onlineResources);

      return onlineResources;
    } catch (e) {
      // If fetch fails and we have cached data, return that
      if (cachedResources.isNotEmpty) {
        return cachedResources;
      }
      // Otherwise, rethrow to let caller handle the error
      rethrow;
    }
  }

  // Assignments methods
  Future<List<AssignmentModel>> getAssignments({
    required Future<List<AssignmentModel>> Function() onlineDataFetcher,
    bool forceRefresh = false,
  }) async {
    // First check local cache
    final cachedAssignments = _localStorage.getAssignments();
    final lastUpdated = _localStorage.getAssignmentsLastUpdated();

    // Return cached data if:
    // 1. We're offline AND we have cached data, OR
    // 2. We're online, not forcing refresh, cache is valid, and we have cached data
    if ((!_connectivity.isConnected && cachedAssignments.isNotEmpty) ||
        (_connectivity.isConnected &&
            !forceRefresh &&
            !_needsRefresh(lastUpdated) &&
            cachedAssignments.isNotEmpty)) {
      return cachedAssignments;
    }

    // If we're offline and don't have cached data, return empty list
    if (!_connectivity.isConnected) {
      return cachedAssignments; // Return empty list or whatever is cached
    }

    // Otherwise fetch from online
    try {
      final onlineAssignments = await onlineDataFetcher();

      // Cache the fetched data
      await _localStorage.saveAssignments(onlineAssignments);

      return onlineAssignments;
    } catch (e) {
      // If fetch fails and we have cached data, return that
      if (cachedAssignments.isNotEmpty) {
        return cachedAssignments;
      }
      // Otherwise, rethrow to let caller handle the error
      rethrow;
    }
  }

  // Assignments by class
  Future<List<AssignmentModel>> getAssignmentsByClass({
    required String classId,
    required Future<List<AssignmentModel>> Function() onlineDataFetcher,
    bool forceRefresh = false,
  }) async {
    // First check local cache
    final cachedAssignments = _localStorage.getAssignmentsByClass(classId);
    final lastUpdated = _localStorage.getAssignmentsLastUpdated();

    // Return cached data if:
    // 1. We're offline AND we have cached data, OR
    // 2. We're online, not forcing refresh, cache is valid, and we have cached data
    if ((!_connectivity.isConnected && cachedAssignments.isNotEmpty) ||
        (_connectivity.isConnected &&
            !forceRefresh &&
            !_needsRefresh(lastUpdated) &&
            cachedAssignments.isNotEmpty)) {
      return cachedAssignments;
    }

    // If we're offline and don't have cached data, return empty list
    if (!_connectivity.isConnected) {
      return cachedAssignments; // Return empty list or whatever is cached
    }

    // Otherwise fetch from online
    try {
      final onlineAssignments = await onlineDataFetcher();

      // Cache the fetched data
      await _localStorage.saveAssignmentsByClass(classId, onlineAssignments);

      return onlineAssignments;
    } catch (e) {
      // If fetch fails and we have cached data, return that
      if (cachedAssignments.isNotEmpty) {
        return cachedAssignments;
      }
      // Otherwise, rethrow to let caller handle the error
      rethrow;
    }
  }

  // Clear cache
  Future<void> clearCache() async {
    try {
      // Clear in-memory caches
      _localStorage.clearAll();

      print('Cache manager cleared all in-memory caches');
    } catch (e) {
      print('Error clearing cache in CacheManager: $e');
    }
  }

  // Get network status
  bool get isOnline => _connectivity.isConnected;

  // Listen to network changes
  Stream<bool> get connectivityStream => _connectivity.connectionChange;

  // Get cached classes without making a network request
  Future<List<ClassModel>> getCachedClasses() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedClassesJson = prefs.getString('cached_classes');

      if (cachedClassesJson != null) {
        final List<dynamic> decodedData = jsonDecode(cachedClassesJson);
        return decodedData.map((item) => ClassModel.fromJson(item)).toList();
      }

      return [];
    } catch (e) {
      print('Error getting cached classes: $e');
      return [];
    }
  }
}
