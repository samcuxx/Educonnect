import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:async';

class ConnectivityService {
  final Connectivity _connectivity = Connectivity();
  bool _isConnected = false;
  StreamController<bool> _connectionChangeController =
      StreamController.broadcast();

  // Initialize service
  void initialize() async {
    // Check initial connection state
    _isConnected = await checkConnectivity();

    // Listen for connectivity changes
    _connectivity.onConnectivityChanged.listen(_updateConnectionStatus);
  }

  // Update connection status and notify listeners
  void _updateConnectionStatus(List<ConnectivityResult> results) async {
    final bool isConnected =
        results.isNotEmpty &&
        results.any((result) => result != ConnectivityResult.none);

    // Only notify if connection status changed
    if (_isConnected != isConnected) {
      _isConnected = isConnected;
      _connectionChangeController.add(_isConnected);
    }
  }

  // Dispose resources
  void dispose() {
    _connectionChangeController.close();
  }

  // Check if the device has any connectivity
  Future<bool> checkConnectivity() async {
    try {
      final List<ConnectivityResult> results =
          await _connectivity.checkConnectivity();

      // If any connection type is available
      return results.isNotEmpty &&
          results.any((result) => result != ConnectivityResult.none);
    } catch (e) {
      print('Error checking connectivity: $e');
      return false;
    }
  }

  // Current connection status
  bool get isConnected => _isConnected;

  // Stream of connectivity changes
  Stream<bool> get connectionChange => _connectionChangeController.stream;
}
