import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../core/time.dart';

/// What went wrong talking to the server, in terms the app can act on.
class ApiException implements Exception {
  ApiException(this.status, this.message, {this.errors = const {}});

  /// HTTP status, or 0 when the server could not be reached at all.
  final int status;
  final String message;
  final Map<String, List<String>> errors;

  bool get isOffline => status == 0;
  bool get isUnauthorized => status == 401;
  bool get isForbidden => status == 403;
  bool get isValidation => status == 422;

  /// The first message the server gave for a field (or the general one).
  String firstMessage([String? field]) {
    if (field != null && (errors[field]?.isNotEmpty ?? false)) return errors[field]!.first;
    for (final messages in errors.values) {
      if (messages.isNotEmpty) return messages.first;
    }
    return message;
  }

  @override
  String toString() => 'ApiException($status, $message)';
}

class LoginResult {
  LoginResult({required this.token, required this.passwordChangeRequired});

  final String token;
  final bool passwordChangeRequired;
}

/// The mobile API (`/api/v1`, see docs/api.md). Knows nothing about the app's state.
class ApiClient {
  ApiClient({required this.baseUrl, this.token, http.Client? client}) : _client = client ?? http.Client();

  String baseUrl;
  String? token;

  /// The language the app shows, so the server's own messages come back in it.
  String? language;
  final http.Client _client;

  static const _timeout = Duration(seconds: 20);

  /// Accepts "192.168.1.5:8000", "my.server" or a full URL; returns one without a trailing slash.
  static String normaliseBaseUrl(String input) {
    var url = input.trim();
    if (url.isEmpty) return url;
    if (!url.contains('://')) url = 'https://$url';
    while (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }
    return url;
  }

  Uri _uri(String path) => Uri.parse('${normaliseBaseUrl(baseUrl)}/api/v1$path');

  Map<String, String> get _headers => {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
        'Accept-Language': ?language,
      };

  Future<Map<String, dynamic>> _send(String method, String path, {Object? body}) async {
    final request = http.Request(method, _uri(path))
      ..headers.addAll(_headers)
      ..body = body == null ? '' : jsonEncode(body);

    http.Response response;
    try {
      response = await http.Response.fromStream(await _client.send(request).timeout(_timeout));
    } on TimeoutException {
      throw ApiException(0, 'timeout');
    } on SocketException catch (e) {
      throw ApiException(0, e.message);
    } on http.ClientException catch (e) {
      throw ApiException(0, e.message);
    } on HandshakeException catch (e) {
      throw ApiException(0, e.message);
    }

    Map<String, dynamic> decoded = {};
    if (response.body.isNotEmpty) {
      try {
        final json = jsonDecode(response.body);
        if (json is Map<String, dynamic>) decoded = json;
        if (json is List) decoded = {'data': json};
      } on FormatException {
        // not JSON (a proxy's error page, say): handled below by status
      }
    }

    if (response.statusCode >= 200 && response.statusCode < 300) return decoded;

    final errors = <String, List<String>>{};
    asMap(decoded['errors']).forEach((field, messages) {
      errors[field] = (messages as List).map((m) => m.toString()).toList();
    });

    throw ApiException(response.statusCode, decoded['message']?.toString() ?? 'error ${response.statusCode}', errors: errors);
  }

  /// Is the server there? (Public, no token needed.)
  Future<bool> isReachable() async {
    try {
      await _send('GET', '/health');
      return true;
    } on ApiException {
      return false;
    }
  }

  Future<LoginResult> login({required String email, required String password, required String deviceName}) async {
    final json = await _send('POST', '/auth/login', body: {
      'email': email,
      'password': password,
      'device_name': deviceName,
    });

    return LoginResult(token: json['token'] as String, passwordChangeRequired: json['password_change_required'] == true);
  }

  /// Returns the new, full token; every other device must sign in again.
  Future<LoginResult> changePassword({
    required String current,
    required String password,
    required String confirmation,
  }) async {
    final json = await _send('PUT', '/me/password', body: {
      'current_password': current,
      'password': password,
      'password_confirmation': confirmation,
    });

    return LoginResult(token: json['token'] as String, passwordChangeRequired: json['password_change_required'] == true);
  }

  Future<void> logout() => _send('POST', '/auth/logout');

  /// Languages, texts, pages and menu links (public). With the version the app already
  /// holds the server answers `{unchanged: true}` when nothing moved.
  Future<Map<String, dynamic>> content({String? version}) =>
      _send('GET', version == null || version.isEmpty ? '/content' : '/content?version=${Uri.encodeQueryComponent(version)}');

  Future<Map<String, dynamic>> me() => _send('GET', '/me');

  Future<List<Map<String, dynamic>>> devices() async {
    final json = await _send('GET', '/me/devices');
    return (json['data'] as List).cast<Map<String, dynamic>>();
  }

  Future<void> removeDevice(int id) => _send('DELETE', '/me/devices/$id');

  // ---- Family administration (family admins only; needs a connection)

  Future<Map<String, dynamic>> family() => _send('GET', '/family');

  Future<Map<String, dynamic>> createMember(Map<String, dynamic> member) => _send('POST', '/family/members', body: member);

  Future<Map<String, dynamic>> updateMember(int id, Map<String, dynamic> member) => _send('PUT', '/family/members/$id', body: member);

  Future<void> deleteMember(int id) => _send('DELETE', '/family/members/$id');

  /// Returns the new temporary password.
  Future<String> resetMemberPassword(int id) async => (await _send('POST', '/family/members/$id/reset-password'))['temporary_password'] as String;

  Future<void> createListType(String name) => _send('POST', '/family/list-types', body: {'name': name});

  Future<void> renameListType(int id, String name) => _send('PUT', '/family/list-types/$id', body: {'name': name});

  Future<void> deleteListType(int id) => _send('DELETE', '/family/list-types/$id');

  Future<Map<String, dynamic>> sync(Map<String, dynamic> payload) => _send('POST', '/sync', body: payload);

  void close() => _client.close();
}
