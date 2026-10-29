import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../data/api_client.dart';
import '../data/repository.dart';
import 'settings_state.dart';

enum AuthStatus { loading, signedOut, mustChangePassword, signedIn }

/// Who is signed in on this phone, and the device token that proves it.
/// The token lives in the Android keystore (secure storage), never in plain preferences.
class AuthState extends ChangeNotifier {
  AuthState({
    required this.api,
    required this.repository,
    required this.settings,
    FlutterSecureStorage? storage,
  }) : _storage = storage ?? const FlutterSecureStorage();

  final ApiClient api;
  final Repository repository;
  final SettingsState settings;
  final FlutterSecureStorage _storage;

  static const _tokenKey = 'device_token';
  static const _stageKey = 'password_change_required';

  AuthStatus _status = AuthStatus.loading;
  AuthStatus get status => _status;

  /// The temporary password just typed to sign in. Kept in memory only, for the
  /// one thing it is needed for: choosing the real password without asking for the old one again.
  String? _temporaryPassword;

  Future<void> init() async {
    api.baseUrl = settings.serverUrl;

    final token = await _readToken();
    if (token == null) {
      _set(AuthStatus.signedOut);
      return;
    }

    api.token = token;
    final mustChange = await _storage.read(key: _stageKey) == 'true';
    if (mustChange) {
      // The app was closed halfway through the first login, and the temporary password
      // only ever lived in memory: sign in again (it is the same easy password).
      await _signedOut();
      return;
    }

    _set(AuthStatus.signedIn);
  }

  Future<String?> _readToken() async {
    try {
      return await _storage.read(key: _tokenKey);
    } catch (_) {
      return null; // an unreadable keystore means signing in again
    }
  }

  /// Throws [ApiException] (wrong password, offline, too many attempts...).
  Future<void> login({required String serverUrl, required String email, required String password}) async {
    final url = ApiClient.normaliseBaseUrl(serverUrl);
    api
      ..baseUrl = url
      ..token = null;

    final result = await api.login(email: email.trim(), password: password, deviceName: await _deviceName());

    await settings.setServerUrl(url);
    _temporaryPassword = result.passwordChangeRequired ? password : null;
    await _storeToken(result.token, mustChange: result.passwordChangeRequired);
    _set(result.passwordChangeRequired ? AuthStatus.mustChangePassword : AuthStatus.signedIn);
  }

  /// Change the password (settings): needs the current one.
  Future<void> changePassword({required String current, required String password, required String confirmation}) async {
    final result = await api.changePassword(current: current, password: password, confirmation: confirmation);

    await _storeToken(result.token, mustChange: result.passwordChangeRequired);
    _set(result.passwordChangeRequired ? AuthStatus.mustChangePassword : AuthStatus.signedIn);
  }

  /// First login: choose the real password. The temporary one, which was just typed to
  /// sign in, is sent along for the person, so only the new one is asked for.
  Future<void> choosePassword({required String password, required String confirmation}) async {
    final temporary = _temporaryPassword;
    if (temporary == null) {
      await _signedOut();
      return;
    }

    await changePassword(current: temporary, password: password, confirmation: confirmation);
    _temporaryPassword = null;
  }

  /// Sign out here (and tell the server, if it can be reached) and forget the family's data.
  Future<void> logout() async {
    try {
      await api.logout();
    } on ApiException {
      // offline or already revoked: signing out locally is what matters
    }
    await _signedOut();
  }

  /// The server no longer accepts this token (revoked from the web, password reset...).
  Future<void> tokenRejected() => _signedOut();

  Future<void> _signedOut() async {
    _temporaryPassword = null;
    api.token = null;
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _stageKey);
    await repository.wipe();
    _set(AuthStatus.signedOut);
  }

  Future<void> _storeToken(String token, {required bool mustChange}) async {
    api.token = token;
    await _storage.write(key: _tokenKey, value: token);
    await _storage.write(key: _stageKey, value: mustChange ? 'true' : 'false');
  }

  Future<String> _deviceName() async {
    try {
      if (Platform.isAndroid) {
        final info = await DeviceInfoPlugin().androidInfo;
        return '${info.manufacturer} ${info.model}'.trim();
      }
    } catch (_) {
      // falls through to a generic name
    }
    return 'Phone';
  }

  void _set(AuthStatus status) {
    _status = status;
    notifyListeners();
  }
}
