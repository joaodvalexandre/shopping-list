import 'dart:io';

import 'package:flutter/services.dart';

import '../peer/nearby_service.dart';
import 'auth_state.dart';
import 'settings_state.dart';

/// Keeps a local family connected while the phone is locked: Android only lets an app go on
/// running with a notification that stays, and this is the one that says how the family link is.
/// Only for a local family (a server family asks the server, and has notifications for that).
class FamilyLink {
  FamilyLink({required this.auth, required this.nearby, required this.settings, this.displayName, MethodChannel? channel})
      : _channel = channel ?? const MethodChannel('app.familyshopper.mobile/family_link') {
    auth.addListener(update);
    nearby.addListener(update);
    settings.addListener(update);
  }

  final AuthState auth;
  final NearbyService nearby;
  final SettingsState settings;
  final MethodChannel _channel;
  final String Function(String name)? displayName;

  bool _running = false;
  String? _text;

  /// An offline family always (its phones only talk through the app); a server family when the person
  /// asked for the app to keep running, to be told at once what others do.
  bool get _wanted {
    if (auth.status != AuthStatus.signedIn) return false;
    return auth.isLocal ? nearby.enabled : settings.keepRunning;
  }

  /// What the notification says: connected to someone, syncing, or looking.
  String get statusText {
    if (!auth.isLocal) return settings.t('app_link_watching');

    final who = displayName?.call(nearby.currentPeer ?? '') ?? nearby.currentPeer ?? '';

    return switch (nearby.state) {
      NearbyState.connected => settings.t('app_link_connected', {'name': who}),
      NearbyState.syncing => settings.t('app_link_syncing', {'name': who}),
      NearbyState.connecting => settings.t('app_link_connecting', {'name': who}),
      _ => settings.t('app_link_searching'),
    };
  }

  Future<void> update() async {
    if (!_wanted) {
      if (_running) {
        _running = false;
        _text = null;
        await _call('stop');
      }
      return;
    }

    final text = statusText;
    if (_running && text == _text) return;

    final title = settings.t(auth.isLocal ? 'app_link_title' : 'app_link_title_online');
    final wasRunning = _running;
    _running = true;
    _text = text;

    // Already showing: only the words change (starting a service from the background is not always allowed)
    final arguments = {'title': title, 'text': text, 'close': settings.t('app_link_close')};
    if (wasRunning && await _call('update', arguments) == true) return;

    // Android said no: not running, so the next change tries again
    if (await _call('start', arguments) == false) {
      _running = false;
      _text = null;
    }
  }

  /// Is the app allowed to run in the background without being stopped to save battery? (Android only.)
  Future<bool> batteryExempt() async => await _call('batteryExempt') == true;

  /// Open Android's question: let the app run in the background. Said "no" to, the phone may stop
  /// the app when the screen is off, and the family's phones lose each other.
  Future<void> askBatteryExemption() => _call('askBatteryExemption');

  Future<Object?> _call(String method, [Map<String, String>? arguments]) async {
    if (!Platform.isAndroid) return null;

    try {
      return await _channel.invokeMethod<Object?>(method, arguments);
    } on MissingPluginException {
      return null; // tests, or no native side
    } on PlatformException {
      return null;
    }
  }

  void dispose() {
    auth.removeListener(update);
    nearby.removeListener(update);
    settings.removeListener(update);
  }
}
