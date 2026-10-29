import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shopping_list/data/api_client.dart';
import 'package:shopping_list/peer/identity.dart';
import 'package:shopping_list/state/notification_service.dart';

/// A notification sink that remembers what it was asked to show.
class FakeSink implements NoticeSink {
  final shown = <({int id, String title, String body, String payload, List<String> lines, String sound, String channelName})>[];

  /// The sounds played for banners inside the app.
  final played = <String>[];
  bool permission = true;
  int permissionAsks = 0;

  @override
  Future<bool> requestPermission() async {
    permissionAsks++;
    return permission;
  }

  @override
  Future<void> show({
    required int id,
    required String title,
    required String body,
    required String payload,
    List<String> lines = const [],
    String sound = 'added',
    String channelName = '',
  }) async {
    shown.add((id: id, title: title, body: body, payload: payload, lines: lines, sound: sound, channelName: channelName));
  }

  @override
  Future<void> play(String sound) async => played.add(sound);
}

/// An API that answers every request with what [answer] returns, or is unreachable when it returns null.
ApiClient apiAnswering(Map<String, dynamic>? Function(Uri uri) answer) => ApiClient(
      baseUrl: 'http://server',
      client: MockClient((request) async {
        final body = answer(request.url);
        if (body == null) throw http.ClientException('no network');
        return http.Response(jsonEncode(body), 200);
      }),
    );

/// The phone's keystore, in memory.
class MemorySecrets implements SecretStore {
  final values = <String, String>{};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;
}
