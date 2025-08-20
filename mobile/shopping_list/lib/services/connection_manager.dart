import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'web_api_service.dart';

class ConnectionManager {
  static final ConnectionManager _instance = ConnectionManager._internal();
  factory ConnectionManager() => _instance;
  ConnectionManager._internal();

  final WebApiService _webApiService = WebApiService();
  final Connectivity _connectivity = Connectivity();

  bool _isConnected = false;
  bool _isWebappAvailable = false;
  Timer? _connectionCheckTimer;

  // Stream controllers for connection status updates
  final StreamController<bool> _connectionStatusController = StreamController<bool>.broadcast();
  final StreamController<bool> _webappStatusController = StreamController<bool>.broadcast();

  // Getters
  bool get isConnected => _isConnected;
  bool get isWebappAvailable => _isWebappAvailable;
  Stream<bool> get connectionStatusStream => _connectionStatusController.stream;
  Stream<bool> get webappStatusStream => _webappStatusController.stream;

  // Initialize connection monitoring
  Future<void> initialize() async {
    // Listen to connectivity changes
    _connectivity.onConnectivityChanged.listen(_onConnectivityChanged);

    // Initial connection check
    await _checkConnection();

    // Set up periodic connection checks
    _connectionCheckTimer = Timer.periodic(
      const Duration(minutes: 2), // Check every 2 minutes
      (_) => _checkConnection(),
    );
  }

  // Handle connectivity changes
  void _onConnectivityChanged(ConnectivityResult result) {
    final wasConnected = _isConnected;
    _isConnected = result != ConnectivityResult.none;

    if (wasConnected != _isConnected) {
      _connectionStatusController.add(_isConnected);

      // If we just got connection, check webapp availability
      if (_isConnected) {
        _checkWebappAvailability();
      } else {
        _isWebappAvailable = false;
        _webappStatusController.add(false);
      }
    }
  }

  // Check internet connection
  Future<void> _checkConnection() async {
    try {
      final result = await _connectivity.checkConnectivity();
      final wasConnected = _isConnected;
      _isConnected = result != ConnectivityResult.none;

      if (wasConnected != _isConnected) {
        _connectionStatusController.add(_isConnected);
      }

      // If connected, check webapp availability
      if (_isConnected) {
        await _checkWebappAvailability();
      }
    } catch (e) {
      _isConnected = false;
      _connectionStatusController.add(false);
    }
  }

  // Check if webapp is available
  Future<void> _checkWebappAvailability() async {
    try {
      final isAvailable = await _webApiService.testConnection();
      final wasAvailable = _isWebappAvailable;
      _isWebappAvailable = isAvailable;

      if (wasAvailable != _isWebappAvailable) {
        _webappStatusController.add(_isWebappAvailable);
      }
    } catch (e) {
      _isWebappAvailable = false;
      _webappStatusController.add(false);
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
  void dispose() {
    _connectionCheckTimer?.cancel();
    _connectionStatusController.close();
    _webappStatusController.close();
  }
}
