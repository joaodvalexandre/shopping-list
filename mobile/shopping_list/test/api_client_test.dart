import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shopping_list/data/api_client.dart';

void main() {
  test('server addresses are tidied', () {
    expect(ApiClient.normaliseBaseUrl('lists.example.com'), 'https://lists.example.com');
    expect(ApiClient.normaliseBaseUrl(' http://localhost:8000/ '), 'http://localhost:8000');
    expect(ApiClient.normaliseBaseUrl('https://a.b/c//'), 'https://a.b/c');
    expect(ApiClient.normaliseBaseUrl(''), '');
  });

  test('logs in with the device name and returns the token', () async {
    late http.Request seen;
    final api = ApiClient(
      baseUrl: 'http://server',
      client: MockClient((request) async {
        seen = request;
        return http.Response(jsonEncode({'token': '1|abc', 'password_change_required': true}), 200);
      }),
    );

    final result = await api.login(email: 'a@b.c', password: 'Silva', deviceName: 'Pixel');

    expect(seen.url.toString(), 'http://server/api/v1/auth/login');
    expect(jsonDecode(seen.body), {'email': 'a@b.c', 'password': 'Silva', 'device_name': 'Pixel'});
    expect(seen.headers['Accept'], 'application/json');
    expect(result.token, '1|abc');
    expect(result.passwordChangeRequired, isTrue);
  });

  test('sends the token and reads validation errors', () async {
    final api = ApiClient(
      baseUrl: 'http://server',
      token: 'secret',
      client: MockClient((request) async {
        expect(request.headers['Authorization'], 'Bearer secret');
        return http.Response(jsonEncode({'message': 'Invalid', 'errors': {'password': ['Too short', 'Needs a number']}}), 422);
      }),
    );

    try {
      await api.changePassword(current: 'a', password: 'b', confirmation: 'b');
      fail('should have thrown');
    } on ApiException catch (e) {
      expect(e.isValidation, isTrue);
      expect(e.firstMessage('password'), 'Too short');
      expect(e.firstMessage('other'), 'Too short'); // falls back to the first message there is
    }
  });

  test('tells a lost connection from a refusal', () async {
    final offline = ApiClient(baseUrl: 'http://server', client: MockClient((_) async => throw http.ClientException('no route')));
    expect(() => offline.me(), throwsA(isA<ApiException>().having((e) => e.isOffline, 'offline', isTrue)));

    final revoked = ApiClient(baseUrl: 'http://server', client: MockClient((_) async => http.Response('{"message":"Unauthenticated."}', 401)));
    expect(() => revoked.me(), throwsA(isA<ApiException>().having((e) => e.isUnauthorized, 'unauthorized', isTrue)));

    final html = ApiClient(baseUrl: 'http://server', client: MockClient((_) async => http.Response('<html>Bad gateway</html>', 502)));
    expect(() => html.me(), throwsA(isA<ApiException>().having((e) => e.status, 'status', 502)));
  });

  test('knows whether the server is reachable', () async {
    final up = ApiClient(baseUrl: 'http://server', client: MockClient((_) async => http.Response('{"status":"ok"}', 200)));
    final down = ApiClient(baseUrl: 'http://server', client: MockClient((_) async => throw http.ClientException('x')));

    expect(await up.isReachable(), isTrue);
    expect(await down.isReachable(), isFalse);
  });

  test('tells the server which language the app shows', () async {
    late http.Request seen;
    final api = ApiClient(
      baseUrl: 'http://server',
      client: MockClient((request) async {
        seen = request;
        return http.Response(jsonEncode({'members': [], 'list_types': []}), 200);
      }),
    );

    await api.family();
    expect(seen.headers.containsKey('Accept-Language'), isFalse);

    api.language = 'pt';
    await api.family();
    expect(seen.headers['Accept-Language'], 'pt');
    expect(seen.url.toString(), 'http://server/api/v1/family');
  });
}
