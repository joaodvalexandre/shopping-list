import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shopping_list/data/api_client.dart';
import 'package:shopping_list/data/content.dart';
import 'package:shopping_list/state/content_service.dart';

import 'support/memory_store.dart';

Map<String, dynamic> payload({String version = 'v1', String privacy = 'Privacy'}) => {
      'version': version,
      'languages': [
        {'code': 'pt', 'name': 'Portuguese', 'native_name': 'Português', 'is_default': true},
        {'code': 'en', 'name': 'English', 'native_name': 'English', 'is_default': false},
      ],
      'texts': {
        'pt': {'login': 'Entrar'},
        'en': {'login': 'Log in', 'only_en': 'Only English'},
      },
      'pages': [
        {
          'slug': 'privacy',
          'title': {'pt': 'Privacidade', 'en': privacy},
          'content': {'pt': '<p>Texto</p>', 'en': '<p>Text</p>'},
        },
      ],
      'menu': [
        {'id': 1, 'parent_id': null, 'location': 'footer', 'audience': 'everyone', 'label': {'pt': 'Legal', 'en': 'Legal'}, 'page': null, 'url': null, 'new_tab': false},
        {'id': 2, 'parent_id': 1, 'location': 'footer', 'audience': 'everyone', 'label': {'pt': 'Privacidade', 'en': 'Privacy'}, 'page': 'privacy', 'url': null, 'new_tab': false},
        {'id': 3, 'parent_id': null, 'location': 'footer', 'audience': 'members', 'label': {'pt': 'Só membros', 'en': 'Members only'}, 'page': 'privacy', 'url': null, 'new_tab': false},
        {'id': 4, 'parent_id': null, 'location': 'footer', 'audience': 'family_admins', 'label': {'pt': 'Admins'}, 'page': null, 'url': 'https://example.com', 'new_tab': true},
        {'id': 5, 'parent_id': null, 'location': 'footer', 'audience': 'guests', 'label': {'pt': 'Visitantes', 'en': 'Guests'}, 'page': null, 'url': 'https://example.com/guest', 'new_tab': false},
        {'id': 6, 'parent_id': null, 'location': 'footer', 'audience': 'everyone', 'label': {'pt': 'Vazio'}, 'page': null, 'url': null, 'new_tab': false},
      ],
    };

ApiClient apiAnswering(Map<String, dynamic> Function(Uri uri) answer) =>
    ApiClient(baseUrl: 'http://server', client: MockClient((request) async => http.Response(jsonEncode(answer(request.url)), 200)));

void main() {
  late MemoryStore store;
  late ContentService content;

  setUp(() async {
    store = MemoryStore();
    content = await ContentService.load(store, bundled: () async => jsonEncode(payload()));
  });

  test('a fresh install starts from the shipped copy and keeps it in the local database', () {
    expect(content.version, 'v1');
    expect(store.content?.version, 'v1');
    expect(content.languages.map((l) => l.code), ['pt', 'en']);
    expect(content.defaultLanguage, 'pt');
    expect(content.text('pt', 'login'), 'Entrar');
    expect(content.titleOf(content.page('privacy')!, 'en'), 'Privacy');
  });

  test('later starts use the local copy, not the shipped one', () async {
    store.content = ContentSnapshot.fromJson(payload(version: 'newer'));

    final again = await ContentService.load(store, bundled: () async => fail('must not be read'));

    expect(again.version, 'newer');
  });

  test('menus show each person the links meant for them, headings with their links', () {
    List<String> labels(Viewer viewer, {String language = 'en'}) =>
        content.links('footer', language: language, viewer: viewer).map((l) => l.label).toList();

    expect(labels(Viewer.guest), ['Legal', 'Guests']);                        // "Empty" has nothing under it
    expect(labels(Viewer.member), ['Legal', 'Members only']);
    expect(labels(Viewer.familyAdmin), ['Legal', 'Members only', 'Admins']);   // no English label: the default language's

    final legal = content.links('footer', language: 'pt', viewer: Viewer.guest).first;
    expect(legal.children.single.label, 'Privacidade');
    expect(legal.children.single.page, 'privacy');
    expect(content.links('navbar', language: 'en', viewer: Viewer.member), isEmpty);
  });

  test('a missing text or title falls back to the default language', () {
    expect(content.text('en', 'only_en'), 'Only English');
    expect(content.text('pt', 'only_en'), isNull);
    expect(content.hasLanguage('en'), isTrue);
    expect(content.hasLanguage('xx'), isFalse);
  });

  test('refresh stores what the server changed and tells listeners', () async {
    var notified = 0;
    content.addListener(() => notified++);
    Uri? asked;

    final changed = await content.refresh(apiAnswering((uri) {
      asked = uri;
      return payload(version: 'v2', privacy: 'Privacy notice');
    }));

    expect(changed, isTrue);
    expect(asked.toString(), 'http://server/api/v1/content?version=v1');
    expect(notified, 1);
    expect(content.titleOf(content.page('privacy')!, 'en'), 'Privacy notice');
    expect(store.content?.version, 'v2');
  });

  test('refresh leaves everything alone when nothing changed, or the server cannot be reached', () async {
    var notified = 0;
    content.addListener(() => notified++);

    expect(await content.refresh(apiAnswering((_) => {'version': 'v1', 'unchanged': true})), isFalse);

    final offline = ApiClient(baseUrl: 'http://server', client: MockClient((_) async => throw http.ClientException('no network')));
    expect(await content.refresh(offline), isFalse);

    // an empty answer never replaces a working copy
    expect(await content.refresh(apiAnswering((_) => {'version': 'v9', 'languages': []})), isFalse);

    expect(notified, 0);
    expect(content.version, 'v1');
  });

  test('PHP sends empty objects as lists', () {
    final snapshot = ContentSnapshot.fromJson({'version': 'x', 'languages': [], 'texts': [], 'pages': [], 'menu': []});

    expect(snapshot.texts, isEmpty);
  });
}
