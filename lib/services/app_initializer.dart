import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'connectivity_service.dart';
import 'local_storage_service.dart';
import 'cache_manager.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';

final getIt = GetIt.instance;

class AppInitializer {
  // Singleton instance
  static final AppInitializer _instance = AppInitializer._internal();
  factory AppInitializer() => _instance;
  AppInitializer._internal();

  // Services
  final ConnectivityService _connectivityService = ConnectivityService();
  final LocalStorageService _localStorageService = LocalStorageService();
  final CacheManager _cacheManager = CacheManager();

  // Initialization state
  bool _isInitialized = false;

  // Initialize all services
  Future<void> initialize() async {
    if (_isInitialized) return;

    // Initialize Hive and local storage
    await Hive.initFlutter();
    await _localStorageService.initialize();

    // Initialize connectivity service
    _connectivityService.initialize();

    // Initialize cache manager
    await _cacheManager.initialize();

    _isInitialized = true;
  }

  // Cleanup resources
  void dispose() {
    _connectivityService.dispose();
  }

  // Get connectivity status
  bool get isOnline => _connectivityService.isConnected;

  // Get stream of connectivity changes
  Stream<bool> get connectivityChanges => _connectivityService.connectionChange;

  // Initialize all services
  static Future<void> initializeApp() async {
    // Register services
    await _registerServices();
  }

  // Register services in GetIt service locator
  static Future<void> _registerServices() async {
    // Shared preferences
    final sharedPreferences = await SharedPreferences.getInstance();
    getIt.registerSingleton<SharedPreferences>(sharedPreferences);

    // Connectivity service
    getIt.registerSingleton<ConnectivityService>(ConnectivityService());

    // LocalStorageService
    if (!getIt.isRegistered<LocalStorageService>()) {
      try {
        final storageService = LocalStorageService();
        await storageService.initialize();
        getIt.registerSingleton<LocalStorageService>(storageService);
      } catch (e) {
        print('Error initializing LocalStorageService: $e');
        // Register an empty service to prevent crashes
        getIt.registerSingleton<LocalStorageService>(LocalStorageService());
      }
    }

    // Cache Manager
    if (!getIt.isRegistered<CacheManager>()) {
      getIt.registerSingleton<CacheManager>(CacheManager());

      // Initialize the cache manager after registration
      final cacheManager = getIt<CacheManager>();
      await cacheManager.initialize();
    }
  }

  // Clear all cache data (for sign out)
  Future<void> clearAllCache() async {
    try {
      // Clear local storage
      await _localStorageService.clearAll();

      // Clear cache manager data
      await _cacheManager.clearCache();

      print('AppInitializer: All cache cleared successfully');
    } catch (e) {
      print('Error clearing cache in AppInitializer: $e');
    }
  }

  // Static method to clear all cache
  static Future<void> clearCache() async {
    if (getIt.isRegistered<LocalStorageService>()) {
      await getIt<LocalStorageService>().clearAll();
    }

    if (getIt.isRegistered<CacheManager>()) {
      await getIt<CacheManager>().clearCache();
    }

    print('AppInitializer: All cache cleared via static method');
  }
}

// Extension to add app initializer to WidgetsBinding
extension AppInitializerBinding on WidgetsBinding {
  // Initialize app services during Flutter initialization
  static Future<void> initializeApp() async {
    WidgetsFlutterBinding.ensureInitialized();
    await AppInitializer().initialize();
  }
}
