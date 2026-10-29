import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/repository.dart';
import 'frames.dart';
import 'identity.dart';
import 'radio.dart';
import 'session.dart';

enum NearbyState { off, searching, connecting, syncing, connected }

/// A phone seen nearby: its endpoint name says `version|device|family|person`.
class NearbyPeer {
  NearbyPeer({required this.endpointId, required this.version, required this.device, required this.person, this.family});

  final String endpointId;
  final String version;
  final String device;
  final String person;

  /// A short tag of its family; null for a phone on an older version that did not say.
  final String? family;

  static NearbyPeer? parse(String endpointId, String name) {
    final parts = name.split('|');
    if (parts.length < 3) return null;

    if (parts.length == 3) {
      return NearbyPeer(endpointId: endpointId, version: parts[0], device: parts[1], person: parts[2]);
    }
    return NearbyPeer(endpointId: endpointId, version: parts[0], device: parts[1], family: parts[2], person: parts.sublist(3).join('|'));
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
    this.retryAfter = const Duration(seconds: 5),
    this.linkTimeout = const Duration(seconds: 45),
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

  /// After a call that did not work (Bluetooth is not always quick): the first wait, which grows with each failure.
  final Duration retryAfter;

  /// A connection that has neither finished nor failed by then is dropped, so it cannot block the next one.
  final Duration linkTimeout;

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
  final _failures = <String, int>{};
  final _retryNotBefore = <String, DateTime>{};
  Timer? _watchdog;
  String? _familyTag;

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

  /// The device name phones show each other: version, device, family tag and person.
  String get endpointName => '$appVersion|$deviceId|${_familyTag ?? ''}|${personName()}';

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
    } else if (_running) {
      _meetSoonIfChanged();
    }
  }

  /// Something changed here since the last meeting with a phone in sight: no need to wait for the next round.
  void _meetSoonIfChanged() {
    final link = _link;
    if (link != null) {
      // Already connected to a phone: a new round over the same connection
      if (_isIdle(link) && repository.pendingCount != _pendingAtMeeting[link.peer.device]) _runRound(link);
      return;
    }

    for (final peer in _seen.values) {
      final before = _pendingAtMeeting[peer.device];
      if (before != null && before != repository.pendingCount) {
        _call(peer);
        return;
      }
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
      _familyTag = await identity.familyTag();

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
    _failures.clear();
    _retryNotBefore.clear();
    _watchdog?.cancel();
    _seen.clear();
    _otherVersion = null;

    final link = _link;
    _link = null;
    link?.finished = true;
    link?.nextRound?.cancel();
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

    // Another family: not even a connection (a stranger's phone must not keep ours busy)
    if (peer.family != _familyTag) return;

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
    // Connected to another phone and idle: it is this one's turn now
    final standing = _link;
    if (standing != null && _isIdle(standing) && standing.peer.device != peer.device && _seen.containsKey(peer.endpointId) && _due(peer)) {
      _letGo(standing);
    }

    final retryIn = _retryIn(peer);

    if (!_running || _link != null || !_seen.containsKey(peer.endpointId) || retryIn > Duration.zero || !_due(peer)) {
      // try again a little later: they stay in sight for as long as they are in range
      if (_running && _seen.containsKey(peer.endpointId)) {
        _scheduleCall(peer, _link != null ? retryAfter : (retryIn > Duration.zero ? retryIn : meetAgainAfter));
      }
      return;
    }

    _currentPeer = peer.person;
    final link = _link = _Link(peer.endpointId, peer);
    _armWatchdog(link);
    _set(NearbyState.connecting);
    await radio.connect(peer.endpointId, name: endpointName);
  }

  void _scheduleCall(NearbyPeer peer, Duration delay) {
    if (!_running || !_seen.containsKey(peer.endpointId)) return;

    _waitingToCall[peer.endpointId]?.cancel();
    _waitingToCall[peer.endpointId] = Timer(delay, () => _call(peer));
  }

  /// How much longer to leave a phone alone after a call to it failed.
  Duration _retryIn(NearbyPeer peer) {
    final notBefore = _retryNotBefore[peer.device];
    if (notBefore == null) return Duration.zero;

    final left = notBefore.difference(DateTime.now());
    return left > Duration.zero ? left : Duration.zero;
  }

  void _armWatchdog(_Link link) {
    _watchdog?.cancel();
    _watchdog = Timer(linkTimeout, () {
      if (_link != link) return;

      radio.disconnect(link.endpointId);
      _finish(link, PeerResult(PeerStatus.timeout));
    });
  }

  // ---------------------------------------------------------- the connection

  void _onInitiated(String endpointId, String name) {
    final peer = NearbyPeer.parse(endpointId, name);

    final standing = _link;
    if (standing != null && peer != null && _isIdle(standing) && standing.endpointId != endpointId && peer.version == appVersion && peer.family == _familyTag) {
      _letGo(standing); // connected to another phone and idle: this one is waiting
    }

    // One at a time, and only phones on the same version
    if (peer == null || peer.version != appVersion || peer.family != _familyTag || (_link != null && _link!.endpointId != endpointId)) {
      radio.reject(endpointId);
      return;
    }

    if (_link == null) {
      final link = _link = _Link(endpointId, peer);
      _armWatchdog(link);
    }
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

    link.established = true;
    _runRound(link);
  }

  void _onDisconnected(String endpointId) {
    final link = _link;
    if (link == null || link.endpointId != endpointId) return;

    link.channel.close(); // a round under way ends by itself, with what it had
    if (!link.sessionActive) _finish(link, null, graceful: link.rounds > 0);
  }

  void _onReceived(String endpointId, Uint8List bytes) {
    final link = _link;
    if (link == null || link.endpointId != endpointId) return;

    final message = link.assembler.add(bytes);
    if (message == null) return;

    if (!link.sessionActive) {
      // Between rounds only a new "hello" means something: the other phone has news
      if (message['t'] != 'hello') return;
      _runRound(link);
    }
    link.channel.deliver(message);
  }

  bool _isIdle(_Link link) => link.established && !link.sessionActive && !link.finished;

  /// One meeting over the connection: hello, proof, ready, offer, done. The connection is kept
  /// afterwards, so the next round (when something changes, on either phone) needs no new connection.
  Future<void> _runRound(_Link link) async {
    if (link.sessionActive || link.finished || !_running) return;

    link.sessionActive = true;
    _set(NearbyState.syncing);

    // Sending needs the radio: the channel hands whole messages to it
    final channel = link.channel = _RadioChannel(nextId: () => link.messageIds++)
      ..sender = (frame) => radio.send(link.endpointId, frame);

    final session = PeerSession(
      identity: identity,
      repository: repository,
      appVersion: appVersion,
      channel: channel,
      displayName: personName(),
    );

    PeerResult result;
    try {
      result = await session.run();
    } catch (_) {
      result = PeerResult(PeerStatus.protocol);
    }

    link.sessionActive = false;
    await channel.close();
    if (link.finished) return;

    if (result.status == PeerStatus.done) {
      _roundDone(link, result);
      return;
    }

    await radio.disconnect(link.endpointId);
    _finish(link, result);
  }

  void _roundDone(_Link link, PeerResult result) {
    link.rounds++;
    _watchdog?.cancel();

    final peer = link.peer;
    _failures.remove(peer.device);
    _retryNotBefore.remove(peer.device);
    _lastMeeting[peer.device] = DateTime.now();
    _pendingAtMeeting[peer.device] = repository.pendingCount;
    _lastResult = result;
    _lastMeetingAt = DateTime.now();

    // Another phone of the family is waiting for its turn (one connection at a time): let go
    if (_seen.values.any((other) => other.device != peer.device && _due(other))) {
      _letGo(link);
      return;
    }

    // Stay connected: a round when something changes here (or the other phone says so), and now and then anyway
    link.nextRound?.cancel();
    link.nextRound = Timer(meetAgainAfter, () => _runRound(link));
    _currentPeer = peer.person;
    _set(NearbyState.connected);
  }

  /// End a connection that worked, for another phone to have its turn.
  void _letGo(_Link link) {
    radio.disconnect(link.endpointId);
    _finish(link, null, graceful: true);
  }

  /// A call that never became a meeting: worth trying again soon (the others, even a refusal, are not).
  static const _failed = {PeerStatus.protocol, PeerStatus.disconnected, PeerStatus.timeout};

  void _finish(_Link link, PeerResult? result, {bool graceful = false}) {
    if (link.finished) return;
    link.finished = true;

    _watchdog?.cancel();
    link.nextRound?.cancel();
    if (_link == link) _link = null;
    link.channel.close();
    _currentPeer = null;

    final peer = link.peer;
    if (!graceful && (result == null || _failed.contains(result.status))) {
      final failures = _failures[peer.device] = (_failures[peer.device] ?? 0) + 1;
      final wait = retryAfter * (failures > 6 ? 6 : failures);

      _retryNotBefore[peer.device] = DateTime.now().add(wait);
      _scheduleCall(peer, wait);
    } else {
      _failures.remove(peer.device);
      _retryNotBefore.remove(peer.device);
      if (result != null) {
        _lastMeeting[peer.device] = DateTime.now();
        _pendingAtMeeting[peer.device] = repository.pendingCount;
      }

      // The connection is over (let go or lost): the next call is soon, to be connected again
      _scheduleCall(peer, link.rounds > 0 ? retryAfter : (shouldCall(deviceId, peer.device) ? meetAgainAfter : meetAgainAfter + callAfterWaiting));
    }

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
  _RadioChannel channel = _RadioChannel(nextId: () => 0);
  int messageIds = 0;
  bool established = false;
  bool sessionActive = false;
  bool finished = false;
  int rounds = 0;
  Timer? nextRound;
}

class _RadioChannel implements PeerChannel {
  _RadioChannel({required this.nextId});

  final _incoming = StreamController<Map<String, dynamic>>();
  Future<void> Function(Uint8List frame)? sender;

  /// Frames carry a message number that must not repeat on the connection, whichever round it is.
  final int Function() nextId;

  @override
  Stream<Map<String, dynamic>> get messages => _incoming.stream;

  void deliver(Map<String, dynamic> message) {
    if (!_incoming.isClosed) _incoming.add(message);
  }

  @override
  Future<void> send(Map<String, dynamic> message) async {
    final send = sender;
    if (send == null) return;

    for (final frame in Frames.split(message, nextId())) {
      await send(frame);
    }
  }

  @override
  Future<void> close() async {
    if (!_incoming.isClosed) await _incoming.close();
  }
}
