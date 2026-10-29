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
  SyncService({
    required this.api,
    required this.repository,
    required this.auth,
    this.onSynced,
    this.watchEvery = const Duration(seconds: 4),
    this.connectivityChanges,
    this.keepInBackground,
  }) {
    repository.onLocalChange = requestSoon;
  }

  final ApiClient api;
  final Repository repository;
  final AuthState auth;

  /// Called after every successful sync (the notifier looks for what others did).
  final Future<void> Function()? onSynced;

  /// How often, while the app is on screen, the server is asked whether anything changed.
  final Duration watchEvery;

  /// True when the person asked the app to keep running with the screen off or closed: then the
  /// watcher goes on, and what others do is told by notifications at once.
  final bool Function()? keepInBackground;

  /// When the phone's connection changes (the platform's, unless a test provides its own).
  final Stream<List<ConnectivityResult>>? connectivityChanges;

  SyncStatus _status = SyncStatus.idle;
  DateTime? _lastSync;
  String? _lastError;
  List<Rejection> _rejections = [];
  bool _unreachable = false;

  Timer? _debounce;
  Timer? _periodic;
  Timer? _watcher;
  String? _marker;
  bool _watching = false;
  bool _foreground = true;
  StreamSubscription<List<ConnectivityResult>>? _connectivity;
  bool _running = false;
  bool _again = false;

  SyncStatus get status => _status;
  DateTime? get lastSync => _lastSync;
  String? get lastError => _lastError;
  bool get isSyncing => _status == SyncStatus.syncing;

  /// True from a sync that failed for lack of a connection until one succeeds. Unlike [status]
  /// it does not flip while the next attempt is under way, so it can decide whether to look
  /// for phones nearby without switching the radio on and off every half minute.
  bool get serverUnreachable => _unreachable;

  /// Changes the server refused since the last time the app asked.
  List<Rejection> takeRejections() {
    final taken = _rejections;
    _rejections = [];
    return taken;
  }

  void start() {
    if (auth.isLocal) return; // a local family never talks to the server
    // While the server is known to be down the watcher tries it every few seconds, so no need to pile on
    _periodic ??= Timer.periodic(const Duration(seconds: 30), (_) {
      if (!(_unreachable && _watcher != null)) sync();
    });
    _connectivity ??= (connectivityChanges ?? Connectivity().onConnectivityChanged).listen((results) {
      if (results.any((result) => result != ConnectivityResult.none)) sync();
    });
    _startWatching();
    sync();
  }

  /// The watcher only runs while the app is on screen; in the background the phone is left alone.
  void setForeground(bool foreground) {
    _foreground = foreground;
    if (foreground) {
      if (_periodic != null) _startWatching();
    } else if (!(keepInBackground?.call() ?? false)) {
      _stopWatching();
    }
  }

  void _startWatching() {
    if (!_foreground && !(keepInBackground?.call() ?? false)) return;
    _watcher ??= Timer.periodic(watchEvery, (_) => _watch());
  }

  void _stopWatching() {
    _watcher?.cancel();
    _watcher = null;
  }

  /// The "watcher": a tiny request for a marker of what changed. Another phone or the web
  /// changing something makes the marker differ, and the phone syncs at once instead of at the next round.
  ///
  /// It is also how the phone learns, within seconds, that the server has gone (then it looks for phones
  /// nearby instead) and that it is back (then everything is sent and brought up to date).
  Future<void> _watch() async {
    if (_watching || _running || auth.status != AuthStatus.signedIn) return;

    _watching = true;
    try {
      final marker = await api.watch();
      final wasDown = _unreachable;
      final changed = _marker != null && marker != _marker;
      _marker = marker;

      if (wasDown || changed) await sync();
    } on ApiException catch (e) {
      if (e.isUnauthorized) {
        await sync(); // the ordinary sync deals with a token that is no longer good
      } else if (e.isServerDown && !_unreachable) {
        _lastError = e.message;
        _unreachable = true;
        _set(SyncStatus.offline);
      }
    } catch (_) {
      // a hiccup: the ordinary sync keeps its own rounds and does the reporting
    } finally {
      _watching = false;
    }
  }

  void stop() {
    _debounce?.cancel();
    _stopWatching();
    _marker = null;
    _periodic?.cancel();
    _periodic = null;
    _connectivity?.cancel();
    _connectivity = null;
  }

  /// After an edit: wait a moment, so several quick edits go in one round trip.
  void requestSoon() {
    if (auth.status != AuthStatus.signedIn || auth.isLocal) return;
    // With the server down the change waits (phones nearby may take it); the watcher syncs when it is back
    if (_unreachable && _watcher != null) return;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 700), sync);
  }

  Future<void> sync() async {
    if (auth.status != AuthStatus.signedIn || auth.isLocal) return;
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
      _unreachable = false;
      _set(SyncStatus.idle);
      await _rememberMarker();

      // (telling the person what others did is not part of syncing: if it fails, the sync still worked)
      try {
        await onSynced?.call();
      } catch (e, stack) {
        debugPrint('after sync: $e\n$stack');
      }
    } on ApiException catch (e) {
      if (e.isUnauthorized) {
        await auth.tokenRejected();
        _set(SyncStatus.idle);
      } else {
        debugPrint('sync failed: ${e.status} ${e.message}');
        _lastError = e.message;
        _unreachable = e.isServerDown;
        _set(e.isServerDown ? SyncStatus.offline : SyncStatus.error);
      }
    } catch (e, stack) {
      debugPrint('sync failed: $e\n$stack');
      _lastError = e.toString();
      _set(SyncStatus.error);
    } finally {
      _running = false;
    }
  }

  /// What the server looks like now, after our own changes went in: only what happens from here on is news.
  Future<void> _rememberMarker() async {
    try {
      _marker = await api.watch();
    } catch (_) {
      _marker = null; // learned again by the next look
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
