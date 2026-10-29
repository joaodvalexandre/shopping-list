import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/repository.dart';
import 'frames.dart';
import 'identity.dart';
import 'radio.dart';
import 'session.dart';

enum NearbyState { off, searching, connecting, syncing }

/// A phone seen nearby: its endpoint name says `version|device|person`.
class NearbyPeer {
  NearbyPeer({required this.endpointId, required this.version, required this.device, required this.person});

  final String endpointId;
  final String version;
  final String device;
  final String person;

  static NearbyPeer? parse(String endpointId, String name) {
    final parts = name.split('|');
    if (parts.length < 3) return null;

    return NearbyPeer(endpointId: endpointId, version: parts[0], device: parts[1], person: parts.sublist(2).join('|'));
  }
}

/// Keeps the family's phones in step when there is no way to the server: while the app is
/// open and the server cannot be reached, it looks for other phones nearby that run exactly
/// the same version of the app and belong to the same family, and swaps with them what each
/// has not yet sent to the server. As soon as any phone reaches the server, the ordinary sync
/// sends all of it and brings back whatever else has changed (on the web, or on other phones).
///
/// Both phones look and are visible at once. To avoid two connections to each other, the one
/// whose device id sorts first makes the call; if it does not come, the other makes it after a while.
class NearbyService extends ChangeNotifier {
  NearbyService({
    required this.radio,
    required this.identity,
    required this.repository,
    required this.prefs,
    required this.appVersion,
    required this.deviceId,
    required Listenable trigger,
    required this.offline,
    required this.signedIn,
    required this.personName,
    this.hasPermissions = hasNearbyPermissions,
    this.ensurePermissions = askForNearbyPermissions,
    this.meetAgainAfter = const Duration(seconds: 60),
    this.callAfterWaiting = const Duration(seconds: 12),
  }) : _trigger = trigger {
    _trigger.addListener(_evaluate);
  }

  final NearbyRadio radio;
  final PeerIdentity identity;
  final Repository repository;
  final SharedPreferences prefs;

  /// Version and build, such as "1.1.0+3". Phones only exchange with the very same one.
  final String appVersion;
  final String deviceId;
  final Listenable _trigger;

  /// Can the server be reached? (True once a sync failed for lack of connection.)
  final bool Function() offline;
  final bool Function() signedIn;
  final String Function() personName;
  final Future<bool> Function() hasPermissions;
  final Future<bool> Function() ensurePermissions;
  final Duration meetAgainAfter;
  final Duration callAfterWaiting;

  static const enabledKey = 'nearby_sync';
  static const _askedKey = 'nearby_permission_asked';

  NearbyState _state = NearbyState.off;
  bool _foreground = true;
  bool _running = false;
  bool _starting = false;
  bool _permissionDenied = false;
  bool _radioFailed = false;

  final _seen = <String, NearbyPeer>{};
  final _lastMeeting = <String, DateTime>{};
  final _pendingAtMeeting = <String, int>{};
  final _waitingToCall = <String, Timer>{};

  _Link? _link;

  PeerResult? _lastResult;
  DateTime? _lastMeetingAt;
  String? _otherVersion;
  String? _currentPeer;

  NearbyState get state => _state;
  bool get enabled => prefs.getBool(enabledKey) ?? true;
  bool get permissionDenied => _permissionDenied;
  bool get radioFailed => _radioFailed;

  /// How the last meeting went, and when.
  PeerResult? get lastResult => _lastResult;
  DateTime? get lastMeetingAt => _lastMeetingAt;

  /// The version of a phone nearby that runs another one, while it is nearby.
  String? get otherVersionSeen => _otherVersion;

  /// Who this phone is talking to now.
  String? get currentPeer => _currentPeer;

  /// The device name phones show each other: version, device and person.
  String get endpointName => '$appVersion|$deviceId|${personName()}';

  Future<void> setEnabled(bool on) async {
    await prefs.setBool(enabledKey, on);

    if (on) {
      _permissionDenied = false;
      _radioFailed = false;
      await prefs.remove(_askedKey);   // switching it on asks again
    }
    _evaluate();
    notifyListeners();
  }

  /// Only while the app is open: the radio is not kept on in the background.
  void setForeground(bool foreground) {
    _foreground = foreground;
    _evaluate();
  }

  // ----------------------------------------------------------- when to run

  void _evaluate() {
    final want = enabled && _foreground && signedIn() && offline();

    if (want && !_running && !_starting) {
      _start();
    } else if (!want && (_running || _starting)) {
      _stop();
    }
  }

  Future<void> _start() async {
    _starting = true;

    try {
      if (!await _allowed()) {
        _permissionDenied = true;
        notifyListeners();
        return;
      }
      _permissionDenied = false;

      // Without a credential from the server nobody can be trusted: it is fetched whenever the server is reachable
      if (await identity.credential() == null) {
        _set(NearbyState.off);
        return;
      }

      final started = await radio.start(name: endpointName, events: _events());
      _radioFailed = !started;
      _running = started;
      _set(started ? NearbyState.searching : NearbyState.off);
    } finally {
      _starting = false;
      // things may have changed while the radio was starting
      if (_running && !(enabled && _foreground && signedIn() && offline())) _stop();
    }
  }

  /// Android's question is asked once; after that the answer is only read, so a "no" is not nagged about.
  Future<bool> _allowed() async {
    if (await hasPermissions()) return true;
    if (prefs.getBool(_askedKey) ?? false) return false;

    await prefs.setBool(_askedKey, true);
    return ensurePermissions();
  }

  Future<void> _stop() async {
    _running = false;
    for (final timer in _waitingToCall.values) {
      timer.cancel();
    }
    _waitingToCall.clear();
    _seen.clear();
    _otherVersion = null;

    final link = _link;
    _link = null;
    link?.channel.close();

    await radio.stop();
    _currentPeer = null;
    _set(NearbyState.off);
  }

  RadioEvents _events() => RadioEvents(
        found: _onFound,
        lost: _onLost,
        initiated: _onInitiated,
        result: _onResult,
        disconnected: _onDisconnected,
        received: _onReceived,
      );

  // ------------------------------------------------------------ finding them

  void _onFound(String endpointId, String name) {
    final peer = NearbyPeer.parse(endpointId, name);
    if (peer == null || peer.device == deviceId) return;

    // Another version: not even a connection (and the person is told to update both)
    if (peer.version != appVersion) {
      _otherVersion = peer.version;
      notifyListeners();
      return;
    }

    _seen[endpointId] = peer;

    if (shouldCall(deviceId, peer.device)) {
      _call(peer);
    } else {
      // Their turn to call: if they do not, the call is made after a while
      _waitingToCall[endpointId]?.cancel();
      _waitingToCall[endpointId] = Timer(callAfterWaiting, () => _call(peer));
    }
  }

  void _onLost(String endpointId) {
    _seen.remove(endpointId);
    _waitingToCall.remove(endpointId)?.cancel();
    if (_seen.values.every((p) => p.version == appVersion)) _otherVersion = null;
    notifyListeners();
  }

  /// Of two phones, the one whose device id sorts first makes the call.
  @visibleForTesting
  static bool shouldCall(String mine, String theirs) => mine.compareTo(theirs) < 0;

  /// Is it time to meet this phone? Not just after meeting it, unless something changed here since.
  bool _due(NearbyPeer peer) {
    final last = _lastMeeting[peer.device];
    if (last == null) return true;
    if (repository.pendingCount != _pendingAtMeeting[peer.device]) return true;
    return DateTime.now().difference(last) >= meetAgainAfter;
  }

  Future<void> _call(NearbyPeer peer) async {
    if (!_running || _link != null || !_seen.containsKey(peer.endpointId) || !_due(peer)) {
      // try again a little later: they stay in sight for as long as they are in range
      if (_running && _seen.containsKey(peer.endpointId)) {
        _waitingToCall[peer.endpointId]?.cancel();
        _waitingToCall[peer.endpointId] = Timer(meetAgainAfter, () => _call(peer));
      }
      return;
    }

    _currentPeer = peer.person;
    _link = _Link(peer.endpointId, peer);
    _set(NearbyState.connecting);
    await radio.connect(peer.endpointId, name: endpointName);
  }

  // ---------------------------------------------------------- the connection

  void _onInitiated(String endpointId, String name) {
    final peer = NearbyPeer.parse(endpointId, name);

    // One at a time, and only phones on the same version
    if (peer == null || peer.version != appVersion || (_link != null && _link!.endpointId != endpointId)) {
      radio.reject(endpointId);
      return;
    }

    _link ??= _Link(endpointId, peer);
    _currentPeer = peer.person;
    _set(NearbyState.connecting);
    radio.accept(endpointId);
  }

  void _onResult(String endpointId, bool connected) {
    final link = _link;
    if (link == null || link.endpointId != endpointId) return;

    if (!connected) {
      _finish(link, null);
      return;
    }

    _runSession(link);
  }

  void _onDisconnected(String endpointId) {
    final link = _link;
    if (link != null && link.endpointId == endpointId) link.channel.close();
  }

  void _onReceived(String endpointId, Uint8List bytes) {
    final link = _link;
    if (link == null || link.endpointId != endpointId) return;

    final message = link.assembler.add(bytes);
    if (message != null) link.channel.deliver(message);
  }

  Future<void> _runSession(_Link link) async {
    _set(NearbyState.syncing);

    // Sending needs the radio: the channel hands whole messages to it
    link.channel.sender = (frame) => radio.send(link.endpointId, frame);

    final session = PeerSession(
      identity: identity,
      repository: repository,
      appVersion: appVersion,
      channel: link.channel,
      displayName: personName(),
    );

    PeerResult result;
    try {
      result = await session.run();
    } catch (_) {
      result = PeerResult(PeerStatus.protocol);
    }

    await radio.disconnect(link.endpointId);
    _finish(link, result);
  }

  void _finish(_Link link, PeerResult? result) {
    if (_link == link) _link = null;
    link.channel.close();
    _currentPeer = null;

    _lastMeeting[link.peer.device] = DateTime.now();
    _pendingAtMeeting[link.peer.device] = repository.pendingCount;

    if (result != null) {
      _lastResult = result;
      _lastMeetingAt = DateTime.now();
      if (result.status == PeerStatus.versionMismatch) _otherVersion = result.theirVersion;
    }

    _set(_running ? NearbyState.searching : NearbyState.off);
  }

  void _set(NearbyState state) {
    _state = state;
    notifyListeners();
  }

  @override
  void dispose() {
    _trigger.removeListener(_evaluate);
    for (final timer in _waitingToCall.values) {
      timer.cancel();
    }
    super.dispose();
  }
}

/// One connection to a phone nearby: its messages in pieces, and a way to send them.
class _Link {
  _Link(this.endpointId, this.peer);

  final String endpointId;
  final NearbyPeer peer;
  final assembler = FrameAssembler();
  final channel = _RadioChannel();
}

class _RadioChannel implements PeerChannel {
  final _incoming = StreamController<Map<String, dynamic>>();
  Future<void> Function(Uint8List frame)? sender;
  int _messageId = 0;

  @override
  Stream<Map<String, dynamic>> get messages => _incoming.stream;

  void deliver(Map<String, dynamic> message) {
    if (!_incoming.isClosed) _incoming.add(message);
  }

  @override
  Future<void> send(Map<String, dynamic> message) async {
    final send = sender;
    if (send == null) return;

    for (final frame in Frames.split(message, _messageId++)) {
      await send(frame);
    }
  }

  @override
  Future<void> close() async {
    if (!_incoming.isClosed) await _incoming.close();
  }
}
