import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

import '../data/api_client.dart';
import '../data/repository.dart';
import 'auth_state.dart';

enum SyncStatus { idle, syncing, offline, error }

/// Keeps the phone and the server in step: one `POST /sync` round trip that
/// sends what changed here and brings back what changed elsewhere.
/// Runs soon after every local edit, every half minute while the app is open,
/// when the connection comes back, and when the person asks.
class SyncService extends ChangeNotifier {
  SyncService({required this.api, required this.repository, required this.auth}) {
    repository.onLocalChange = requestSoon;
  }

  final ApiClient api;
  final Repository repository;
  final AuthState auth;

  SyncStatus _status = SyncStatus.idle;
  DateTime? _lastSync;
  String? _lastError;
  List<Rejection> _rejections = [];

  Timer? _debounce;
  Timer? _periodic;
  StreamSubscription<List<ConnectivityResult>>? _connectivity;
  bool _running = false;
  bool _again = false;

  SyncStatus get status => _status;
  DateTime? get lastSync => _lastSync;
  String? get lastError => _lastError;
  bool get isSyncing => _status == SyncStatus.syncing;

  /// Changes the server refused since the last time the app asked.
  List<Rejection> takeRejections() {
    final taken = _rejections;
    _rejections = [];
    return taken;
  }

  void start() {
    _periodic ??= Timer.periodic(const Duration(seconds: 30), (_) => sync());
    _connectivity ??= Connectivity().onConnectivityChanged.listen((results) {
      if (results.any((result) => result != ConnectivityResult.none)) sync();
    });
    sync();
  }

  void stop() {
    _debounce?.cancel();
    _periodic?.cancel();
    _periodic = null;
    _connectivity?.cancel();
    _connectivity = null;
  }

  /// After an edit: wait a moment, so several quick edits go in one round trip.
  void requestSoon() {
    if (auth.status != AuthStatus.signedIn) return;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 700), sync);
  }

  Future<void> sync() async {
    if (auth.status != AuthStatus.signedIn) return;
    if (_running) {
      _again = true; // something changed meanwhile: go round once more afterwards
      return;
    }

    _running = true;
    _set(SyncStatus.syncing);

    try {
      do {
        _again = false;
        await _roundTrip();
      } while (_again);

      _lastSync = DateTime.now();
      _lastError = null;
      _set(SyncStatus.idle);
    } on ApiException catch (e) {
      if (e.isUnauthorized) {
        await auth.tokenRejected();
        _set(SyncStatus.idle);
      } else {
        _lastError = e.message;
        _set(e.isOffline ? SyncStatus.offline : SyncStatus.error);
      }
    } catch (e) {
      _lastError = e.toString();
      _set(SyncStatus.error);
    } finally {
      _running = false;
    }
  }

  Future<void> _roundTrip() async {
    final push = repository.buildPush(await repository.since);
    final response = await api.sync(push.payload);
    final outcome = await repository.applyResponse(response, push.sent);

    if (outcome.rejections.isNotEmpty) {
      _rejections = [..._rejections, ...outcome.rejections];
      _again = true; // fetch the server's version of what was refused straight away
    }
  }

  void _set(SyncStatus status) {
    _status = status;
    notifyListeners();
  }

  @override
  void dispose() {
    stop();
    super.dispose();
  }
}
