import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/repository.dart';
import 'frames.dart';
import 'identity.dart';
import 'local_family.dart';
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
    this.localFamily,
    this.keepInBackground,
    this.onNews,
    this.maxLinks = 5,
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

  /// Set when this phone belongs to a local family (no server): then the connect code, not a
  /// credential from the server, is what makes phones one family.
  final LocalFamilyStore? localFamily;

  /// True when the phone should keep looking for (and talking to) its phones with the app off
  /// screen, which a local family does with a notification showing (an Android foreground service).
  final bool Function()? keepInBackground;

  /// Called after a meeting that brought changes, with what came in and who from: for a notification
  /// when nobody is looking at the app.
  final void Function(PeerResult result)? onNews;

  /// A connection that has neither finished nor failed by then is dropped, so it cannot block the next one.
  final Duration linkTimeout;

  /// How many phones of the family this one stays connected to at once: all of them in range, up
  /// to this many, so that nobody has to wait for a turn and changes pass on through whoever they reach.
  final int maxLinks;

  static const enabledKey = 'nearby_sync';
  static const _askedKey = 'nearby_permission_asked';

  NearbyState _state = NearbyState.off;
  bool _foreground = true;
  bool _running = false;
  bool _starting = false;
  bool _permissionDenied = false;
  bool _radioFailed = false;

  final _seen = <String, NearbyPeer>{};
  final _pendingAtMeeting = <String, int>{};
  final _waitingToCall = <String, Timer>{};
  final _failures = <String, int>{};
  final _retryNotBefore = <String, DateTime>{};
  String? _familyTag;
  LocalFamilyKey? _localKey;

  final _links = <String, _Link>{};

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

  /// Of a local family: the people (their ids in the family) this phone is connected to right now.
  Set<String> get connectedMemberIds => {
        for (final link in _links.values)
          if (link.established && !link.finished && link.memberId != null) link.memberId!,
      };

  /// One of them, or null when there is none.
  String? get connectedMemberId => connectedMemberIds.firstOrNull;

  /// How many phones of the family this one is connected to right now.
  int get linkCount => _links.values.where((link) => link.established && !link.finished).length;

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
    final want = _wanted;

    if (want && !_running && !_starting) {
      _start();
    } else if (!want && (_running || _starting)) {
      _stop();
    } else if (_running) {
      _meetSoonIfChanged();
    }
  }

  bool get _wanted => enabled && (_foreground || (keepInBackground?.call() ?? false)) && signedIn() && offline();

  /// Goes up whenever something changes here that a phone nearby does not have yet.
  int get _changeMark => repository.isLocal ? repository.revision : repository.pendingCount;

  /// Something changed here since the last meeting with a phone in sight: no need to wait for the next round.
  void _meetSoonIfChanged() {
    // Phones already connected: a new round over each connection that has not heard
    for (final link in _links.values.toList()) {
      if (_isIdle(link) && _linkDirty(link)) _runRound(link);
    }

    // Phones in sight that this one is not connected to, and has news for
    for (final peer in _seen.values.toList()) {
      final before = _pendingAtMeeting[peer.device];
      if (before != null && before != _changeMark && _linkToDevice(peer.device) == null) _call(peer);
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

      final local = await localFamily?.current();
      if (local != null) {
        // A local family: whoever knows the code belongs
        _localKey = await LocalFamilyKey.derive(local.code);
        _familyTag = await _localKey!.tag();
      } else {
        _localKey = null;

        // Without a credential from the server nobody can be trusted: it is fetched whenever the server is reachable
        if (await identity.credential() == null) {
          _set(NearbyState.off);
          return;
        }
        _familyTag = await identity.familyTag();
      }

      final started = await radio.start(name: endpointName, events: _events());
      _radioFailed = !started;
      _running = started;
      _set(started ? NearbyState.searching : NearbyState.off);
    } finally {
      _starting = false;
      // things may have changed while the radio was starting
      if (_running && !_wanted) _stop();
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
    _seen.clear();
    _otherVersion = null;

    for (final link in _links.values) {
      link.finished = true;
      link.watchdog?.cancel();
      link.nextRound?.cancel();
      link.channel.close();
    }
    _links.clear();

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

  Future<void> _call(NearbyPeer peer) async {
    final retryIn = _retryIn(peer);

    // Already connected (or connecting) to that phone, or all the connections this phone keeps are taken
    final skip = !_running ||
        !_seen.containsKey(peer.endpointId) ||
        _linkToDevice(peer.device) != null ||
        _links.length >= maxLinks ||
        retryIn > Duration.zero;

    if (skip) {
      // try again a little later: they stay in sight for as long as they are in range
      if (_running && _seen.containsKey(peer.endpointId) && _linkToDevice(peer.device) == null) {
        _scheduleCall(peer, retryIn > Duration.zero ? retryIn : retryAfter);
      }
      return;
    }

    final link = _links[peer.endpointId] = _Link(peer.endpointId, peer);
    _armWatchdog(link);
    _refresh();
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

  /// The connection to a phone (by its device id), if there is one, even one not yet made.
  _Link? _linkToDevice(String device) {
    for (final link in _links.values) {
      if (link.peer.device == device && !link.finished) return link;
    }
    return null;
  }

  void _armWatchdog(_Link link) {
    link.watchdog?.cancel();
    link.watchdog = Timer(linkTimeout, () {
      if (link.finished || _links[link.endpointId] != link) return;

      radio.disconnect(link.endpointId);
      _finish(link, PeerResult(PeerStatus.timeout));
    });
  }

  // ---------------------------------------------------------- the connections

  void _onInitiated(String endpointId, String name) {
    final peer = NearbyPeer.parse(endpointId, name);

    // Only phones of the same family on the same version; one connection per phone; and a limit
    // to how many are kept at once
    final existing = _links[endpointId];
    final duplicate = peer != null && existing == null && _linkToDevice(peer.device) != null;
    final full = existing == null && _links.length >= maxLinks;

    if (peer == null || peer.version != appVersion || peer.family != _familyTag || duplicate || full) {
      radio.reject(endpointId);
      return;
    }

    if (existing == null) {
      final link = _links[endpointId] = _Link(endpointId, peer);
      _armWatchdog(link);
    }
    _refresh();
    radio.accept(endpointId);
  }

  void _onResult(String endpointId, bool connected) {
    final link = _links[endpointId];
    if (link == null) return;

    if (!connected) {
      _finish(link, null);
      return;
    }

    link.established = true;
    _runRound(link);
  }

  void _onDisconnected(String endpointId) {
    final link = _links[endpointId];
    if (link == null) return;

    link.channel.close(); // a round under way ends by itself, with what it had
    if (!link.sessionActive) _finish(link, null, graceful: link.rounds > 0);
  }

  void _onReceived(String endpointId, Uint8List bytes) {
    final link = _links[endpointId];
    if (link == null) return;

    final message = link.assembler.add(bytes);
    if (message == null) return;

    if (!link.sessionActive) {
      // Between rounds only a new "hello" (or, once trusted, "ready") means something: the other phone has news
      final starts = message['t'] == 'hello' || (message['t'] == 'ready' && link.rounds > 0);
      if (!starts) return;
      _runRound(link, fast: message['t'] == 'ready');
    }
    link.channel.deliver(message);
  }

  /// This phone has news for the one it is connected to: edits since the last round started
  /// (for a local family), or changes waiting to be sent (as before).
  bool _linkDirty(_Link link) =>
      repository.isLocal ? repository.editMark != link.editMarkAtStart : _changeMark != _pendingAtMeeting[link.peer.device];

  bool _isIdle(_Link link) => link.established && !link.sessionActive && !link.finished;

  /// Tell the phones this one is connected to what there is to tell, right now (leaving the family
  /// is the case: it must be said before it is forgotten). False when there is no such phone, or
  /// none of them took it in.
  Future<bool> sendNow() async {
    final links = [for (final link in _links.values) if (link.established && !link.finished) link];
    if (links.isEmpty) return false;

    final results = await Future.wait([
      for (final link in links)
        () async {
          for (var i = 0; i < 50 && link.sessionActive && !link.finished; i++) {
            await Future<void>.delayed(const Duration(milliseconds: 100));
          }
          return _runRound(link);
        }(),
    ]);

    return results.any((ok) => ok);
  }

  /// One meeting over a connection: hello, proof, ready, offer, done. The connection is kept
  /// afterwards, so the next round (when something changes, on either phone) needs no new connection.
  Future<bool> _runRound(_Link link, {bool? fast}) async {
    if (link.sessionActive || link.finished || !_running) return false;

    link.sessionActive = true;
    link.editMarkAtStart = repository.editMark;
    link.pendingRelay = false;
    _refresh();

    // Once this phone has been proven to belong, the next rounds skip hello and proof
    final trusted = (fast ?? link.rounds > 0) && link.peerName != null && _localKey != null;

    // Sending needs the radio: the channel hands whole messages to it
    final channel = link.channel = _RadioChannel(nextId: () => link.messageIds++)
      ..sender = (frame) => radio.send(link.endpointId, frame);

    final key = _localKey;
    final Future<PeerResult> Function() meet = key != null
        ? LocalPeerSession(
            key: key,
            repository: repository,
            appVersion: appVersion,
            channel: channel,
            displayName: personName(),
            knownPeer: trusted ? (name: link.peerName!, id: link.memberId) : null,
          ).run
        : PeerSession(
            identity: identity,
            repository: repository,
            appVersion: appVersion,
            channel: channel,
            displayName: personName(),
          ).run;

    PeerResult result;
    try {
      result = await meet();
    } catch (_) {
      result = PeerResult(PeerStatus.protocol);
    }

    link.sessionActive = false;
    await channel.close();
    if (link.finished) return false;

    if (result.status == PeerStatus.done) {
      _roundDone(link, result);
      return true;
    }

    await radio.disconnect(link.endpointId);
    _finish(link, result);
    return false;
  }

  void _roundDone(_Link link, PeerResult result) {
    link.rounds++;
    link.memberId = result.peerId;
    link.peerName = result.peerName;
    link.watchdog?.cancel();
    if (result.applied.total > 0) onNews?.call(result);

    final peer = link.peer;
    _failures.remove(peer.device);
    _retryNotBefore.remove(peer.device);
    _pendingAtMeeting[peer.device] = _changeMark;
    _lastResult = result;
    _lastMeetingAt = DateTime.now();

    // What came in is news for every other phone this one is connected to: it passes through, so
    // that a phone out of the first one's reach still gets it from the one in between
    if (result.applied.changedFamily) _relayFrom(link);

    // Something was done here (or came from another phone) while the round was going: another round now
    if (link.pendingRelay || (repository.isLocal && repository.editMark != link.editMarkAtStart)) {
      _runRound(link);
      return;
    }

    // Stay connected: a round when something changes here (or the other phone says so), and now and then anyway
    link.nextRound?.cancel();
    link.nextRound = Timer(meetAgainAfter, () => _runRound(link));
    _refresh();
  }

  /// Tell the other connected phones that something came in over [from].
  void _relayFrom(_Link from) {
    for (final other in _links.values.toList()) {
      if (identical(other, from) || other.finished || !other.established) continue;

      if (_isIdle(other)) {
        _runRound(other);
      } else {
        other.pendingRelay = true; // a round is going: another follows it
      }
    }
  }

  /// A call that never became a meeting: worth trying again soon (the others, even a refusal, are not).
  static const _failed = {PeerStatus.protocol, PeerStatus.disconnected, PeerStatus.timeout};

  void _finish(_Link link, PeerResult? result, {bool graceful = false}) {
    if (link.finished) return;
    link.finished = true;

    link.watchdog?.cancel();
    link.nextRound?.cancel();
    if (_links[link.endpointId] == link) _links.remove(link.endpointId);
    link.channel.close();

    final peer = link.peer;
    if (!graceful && (result == null || _failed.contains(result.status))) {
      final failures = _failures[peer.device] = (_failures[peer.device] ?? 0) + 1;
      final wait = retryAfter * (failures > 6 ? 6 : failures);

      _retryNotBefore[peer.device] = DateTime.now().add(wait);
      _scheduleCall(peer, wait);
    } else {
      _failures.remove(peer.device);
      _retryNotBefore.remove(peer.device);

      // The connection is over (lost): to be connected again soon, the caller first
      _scheduleCall(peer, link.rounds > 0 ? retryAfter : (shouldCall(deviceId, peer.device) ? meetAgainAfter : meetAgainAfter + callAfterWaiting));
    }

    if (result != null) {
      _lastResult = result;
      _lastMeetingAt = DateTime.now();
      if (result.status == PeerStatus.versionMismatch) _otherVersion = result.theirVersion;
    }

    _refresh();
  }

  /// What this phone is doing, from how its connections are: syncing with one, connected to some,
  /// connecting, or just looking.
  void _refresh() {
    final live = _links.values.where((link) => !link.finished).toList();

    if (!_running) {
      _currentPeer = null;
      _set(NearbyState.off);
      return;
    }

    final connected = live.where((link) => link.established).toList();
    final names = [for (final link in (connected.isNotEmpty ? connected : live)) link.peerName ?? link.peer.person];
    _currentPeer = names.isEmpty ? null : names.join(', ');

    _set(
      live.any((link) => link.sessionActive)
          ? NearbyState.syncing
          : connected.isNotEmpty
              ? NearbyState.connected
              : live.isNotEmpty
                  ? NearbyState.connecting
                  : NearbyState.searching,
    );
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
    for (final link in _links.values) {
      link.watchdog?.cancel();
      link.nextRound?.cancel();
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
  Timer? watchdog;
  String? memberId;
  String? peerName;
  int editMarkAtStart = 0;

  /// Something came in over another connection while a round was going here: another round follows.
  bool pendingRelay = false;
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
