import 'dart:io';

import 'package:flutter/services.dart';

import '../peer/nearby_service.dart';
import 'auth_state.dart';
import 'settings_state.dart';

/// Keeps a local family connected while the phone is locked: Android only lets an app go on
/// running with a notification that stays, and this is the one that says how the family link is.
/// Only for a local family (a server family asks the server, and has notifications for that).
class FamilyLink {
  FamilyLink({required this.auth, required this.nearby, required this.settings, MethodChannel? channel})
      : _channel = channel ?? const MethodChannel('app.cestou.mobile/family_link') {
    auth.addListener(update);
    nearby.addListener(update);
  }

  final AuthState auth;
  final NearbyService nearby;
  final SettingsState settings;
  final MethodChannel _channel;

  bool _running = false;
  String? _text;

  bool get _wanted => auth.isLocal && auth.status == AuthStatus.signedIn && nearby.enabled;

  /// What the notification says: connected to someone, syncing, or looking.
  String get statusText {
    final who = nearby.currentPeer ?? '';

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

    final title = settings.t('app_link_title');
    final wasRunning = _running;
    _running = true;
    _text = text;

    // Already showing: only the words change (starting a service from the background is not always allowed)
    if (wasRunning && await _call('update', {'title': title, 'text': text}) == true) return;
    await _call('start', {'title': title, 'text': text});
  }

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
  }
}
