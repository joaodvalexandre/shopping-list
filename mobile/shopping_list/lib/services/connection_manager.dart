import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'web_api_service.dart';

class ConnectionManager extends ChangeNotifier {
  static ConnectionManager? _instance;

  factory ConnectionManager() {
    _instance ??= ConnectionManager._internal();
    return _instance!;
  }

  ConnectionManager._internal();

  final WebApiService _webApiService = WebApiService();
  final Connectivity _connectivity = Connectivity();

  bool _isConnected = false;
  bool _isWebappAvailable = false;
  Timer? _connectionCheckTimer;
  bool _isInitialized = false;

  // Getters
  bool get isConnected => _isConnected;
  bool get isWebappAvailable => _isWebappAvailable;

  // Initialize connection monitoring
  Future<void> initialize() async {
    if (_isInitialized) return;

          // ConnectionManager initializing

    // Listen to connectivity changes
    _connectivity.onConnectivityChanged.listen(_onConnectivityChanged);

    // Initial connection check
    await _checkConnection();

    // Set up periodic connection checks
    _connectionCheckTimer = Timer.periodic(
      const Duration(minutes: 2), // Check every 2 minutes
      (_) => _checkConnection(),
    );

    _isInitialized = true;
          // ConnectionManager initialized
  }

  // connectivity_plus reports every active transport (e.g. wifi + vpn)
  bool _hasConnection(List<ConnectivityResult> results) {
    return results.any((r) => r != ConnectivityResult.none);
  }

  // Handle connectivity changes
  void _onConnectivityChanged(List<ConnectivityResult> results) {
          // Connectivity changed
    final wasConnected = _isConnected;
    _isConnected = _hasConnection(results);

    if (wasConnected != _isConnected) {
      // Connection status changed
      notifyListeners();

      // If we just got connection, check webapp availability
      if (_isConnected) {
        _checkWebappAvailability();
      } else {
        _isWebappAvailable = false;
        notifyListeners();
      }
    }
  }

  // Check internet connection
  Future<void> _checkConnection() async {
    try {
      final results = await _connectivity.checkConnectivity();
      final wasConnected = _isConnected;
      _isConnected = _hasConnection(results);

      // Connection status updated

      if (wasConnected != _isConnected) {
        // Connection status updated
        notifyListeners();
      }

      // If connected, check webapp availability
      if (_isConnected) {
        await _checkWebappAvailability();
      }
    } catch (e) {
      // Error checking connection
      _isConnected = false;
      notifyListeners();
    }
  }

  // Check if webapp is available
  Future<void> _checkWebappAvailability() async {
    try {
      // Checking webapp availability
      final isAvailable = await _webApiService.testConnection();
      final wasAvailable = _isWebappAvailable;
      _isWebappAvailable = isAvailable;

              // Webapp availability updated

      if (wasAvailable != _isWebappAvailable) {
                  // Webapp status updated
        notifyListeners();
        // Removed auto-import callback - user must manually choose when to sync
      }
    } catch (e) {
      // Error checking webapp availability
      _isWebappAvailable = false;
      notifyListeners();
    }
  }

  // Manually check webapp availability
  Future<bool> checkWebappAvailability() async {
    await _checkWebappAvailability();
    return _isWebappAvailable;
  }

  // Get connection status summary
  Map<String, dynamic> getConnectionStatus() {
    return {
      'isConnected': _isConnected,
      'isWebappAvailable': _isWebappAvailable,
      'canSync': _isConnected && _isWebappAvailable,
      'lastChecked': DateTime.now(),
    };
  }

  // Dispose resources
  @override
  void dispose() {
    _connectionCheckTimer?.cancel();
    super.dispose();
  }
}
