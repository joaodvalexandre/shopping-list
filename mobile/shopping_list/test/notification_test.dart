import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shopping_list/data/activity.dart';
import 'package:shopping_list/data/content.dart';
import 'package:shopping_list/state/content_service.dart';
import 'package:shopping_list/state/notification_service.dart';
import 'package:shopping_list/state/settings_state.dart';

import 'support/fakes.dart';
import 'support/memory_store.dart';

Map<String, dynamic> event(int id, String kind, {String? actor = 'Bia', String list = 'Barbecue', String listUuid = 'list-1', String? item, int? quantity}) => {
      'id': id,
      'kind': kind,
      'actor': actor,
      'list_uuid': listUuid,
      'list': list,
      'item': item,
      'quantity': quantity,
      'at': '2026-10-29T10:00:00+00:00',
    };

final texts = {
  'en': {
    'app_someone': 'Someone',
    'app_notice_item_added': ':name added :item',
    'app_notice_item_added_many': ':name added :count items',
    'app_notice_item_in_cart': ':name put :item in the cart',
    'app_notice_item_in_cart_many': ':name put :count items in the cart',
    'app_notice_item_purchased': ':name bought :item',
    'app_notice_item_purchased_many': ':name bought :count items',
    'app_notice_list_created': ':name created this list',
    'app_channel_bought': 'Purchases',
    'app_notice_item_added_qty': ':name added :item (x:quantity)',
    'app_notice_item_returned': ':name took :item out of the cart',
    'app_notice_item_returned_many': ':name took :count items out of the cart',
    'app_notice_item_changed': ':name changed :item (x:quantity)',
    'app_notice_item_removed': ':name removed :item',
    'app_notice_item_removed_many': ':name removed :count items',
    'app_notice_list_removed': ':name deleted this list',
  },
  'pt': {'app_notice_item_added': ':name adicionou :item'},
};

void main() {
  late MemoryStore store;
  late FakeSink sink;
  late SharedPreferences prefs;
  late NotificationService service;

  Future<void> setUpService({Map<String, Object> values = const {}, String Function(String name)? displayName}) async {
    SharedPreferences.setMockInitialValues({SettingsState.effectiveLanguageKey: 'en', ...values});
    prefs = await SharedPreferences.getInstance();
    store = MemoryStore();
    sink = FakeSink();

    final content = ContentService(
      store,
      ContentSnapshot.fromJson({
        'version': 'v1',
        'languages': [
          {'code': 'en', 'name': 'English', 'native_name': 'English', 'is_default': true},
          {'code': 'pt', 'name': 'Portuguese', 'native_name': 'Português', 'is_default': false},
        ],
        'texts': texts,
      }),
    );

    service = NotificationService(store: store, prefs: prefs, content: content, sink: sink, displayName: displayName);
  }

  setUp(() => setUpService());

  test('the first look only notes where the feed stands, and announces nothing', () async {
    final api = apiAnswering((uri) {
      expect(uri.toString(), 'http://server/api/v1/activity'); // no cursor yet
      return {'data': [], 'last_id': 41};
    });

    expect(await service.check(api, foreground: false), 0);
    expect(store.meta[NotificationService.cursorKey], '41');
    expect(sink.shown, isEmpty);
  });

  test('in the background, news becomes one notification per list, similar things rolled together', () async {
    store.meta[NotificationService.cursorKey] = '10';
    final api = apiAnswering((uri) {
      expect(uri.toString(), 'http://server/api/v1/activity?after=10');
      return {
        'data': [
          event(11, 'item_added', item: 'Sausages', quantity: 4),
          event(12, 'item_added', item: 'Ribs', quantity: 2),
          event(13, 'item_added', item: 'Bread', quantity: 1),
          event(14, 'item_in_cart', item: 'Beer', actor: 'Rui'),
          event(15, 'item_added', item: 'Milk', list: 'Weekly', listUuid: 'list-2'),
        ],
        'last_id': 15,
      };
    });

    expect(await service.check(api, foreground: false), 2);

    final barbecue = sink.shown.firstWhere((n) => n.payload == 'list-1');
    expect(barbecue.title, 'Barbecue');
    expect(barbecue.body, 'Bia added 3 items\nRui put Beer in the cart');

    final weekly = sink.shown.firstWhere((n) => n.payload == 'list-2');
    expect(weekly.title, 'Weekly');
    expect(weekly.body, 'Bia added Milk');

    expect(store.meta[NotificationService.cursorKey], '15');
    expect(sink.shown.map((n) => n.id).toSet(), hasLength(2)); // each its own notification
  });

  test('uses the language the app shows', () async {
    await setUpService(values: {SettingsState.effectiveLanguageKey: 'pt'});
    store.meta[NotificationService.cursorKey] = '1';

    await service.check(apiAnswering((_) => {'data': [event(2, 'item_added', item: 'Salsichas')], 'last_id': 2}), foreground: false);

    expect(sink.shown.single.body, 'Bia adicionou Salsichas');
  });

  test('with the app open nothing is shown, but the cursor moves on', () async {
    store.meta[NotificationService.cursorKey] = '10';

    final shown = await service.check(apiAnswering((_) => {'data': [event(11, 'item_added', item: 'Milk')], 'last_id': 11}), foreground: true);

    expect(shown, 0);
    expect(sink.shown, isEmpty);
    expect(store.meta[NotificationService.cursorKey], '11');
  });

  test('switched off: nothing is shown, and switching on later does not replay the past', () async {
    await service.setEnabled(false);
    store.meta[NotificationService.cursorKey] = '10';

    await service.check(apiAnswering((_) => {'data': [event(11, 'item_added', item: 'Milk')], 'last_id': 11}), foreground: false);

    expect(sink.shown, isEmpty);
    expect(store.meta[NotificationService.cursorKey], '11');
    expect(service.enabled, isFalse);
  });

  test('an unreachable server changes nothing', () async {
    store.meta[NotificationService.cursorKey] = '10';

    expect(await service.check(apiAnswering((_) => null), foreground: false), 0);
    expect(store.meta[NotificationService.cursorKey], '10');
  });

  test('an action by the server itself says someone, and a new list says who made it', () {
    final notices = buildNotices(
      ActivityPage.fromJson({
        'data': [event(1, 'item_purchased', actor: null, item: 'Milk'), event(2, 'list_created', actor: 'Ana', listUuid: 'list-9', list: 'Party')],
        'last_id': 2,
      }).events,
      (key, params) => texts['en']![key]!.replaceAllMapped(RegExp(r':(\w+)'), (m) => '${params[m[1]] ?? m[0]}'),
    );

    expect(notices.firstWhere((n) => n.listUuid == 'list-1').body, 'Someone bought Milk');
    expect(notices.firstWhere((n) => n.listUuid == 'list-9').body, 'Ana created this list');
  });

  test('asks for the phone permission once, and only while notifications are on', () async {
    await service.askPermissionOnce();
    await service.askPermissionOnce();
    expect(sink.permissionAsks, 1);

    await setUpService(values: {NotificationService.enabledKey: false});
    await service.askPermissionOnce();
    expect(sink.permissionAsks, 0);

    sink.permission = false;
    expect(await service.setEnabled(true), isFalse); // switched on, but Android says no
    expect(service.enabled, isTrue);
  });

  test('reads the feed the way PHP sends it', () {
    final page = ActivityPage.fromJson(jsonDecode('{"data":[],"last_id":7}') as Map<String, dynamic>);

    expect(page.events, isEmpty);
    expect(page.lastId, 7);
  });

  group('what others did, in words and where it is told', () {
    String english(String key, Map<String, Object> params) {
      var text = texts['en']![key] ?? key;
      params.forEach((name, value) => text = text.replaceAll(':$name', value.toString()));
      return text;
    }

    ActivityEvent made(String kind, {String? actor = 'Bia', String list = 'Barbecue', String? item, int? quantity, int id = 0}) =>
        ActivityEvent(id: id, kind: kind, actor: actor, listUuid: 'list-1', list: list, item: item, quantity: quantity);

    test('every kind of thing is said as what was done, with how many when it is more than one', () async {
      await setUpService();

      final lines = buildNotices([
        made('item_added', item: 'Sausages', quantity: 4),
        made('item_returned', item: 'Beer', actor: 'Rui'),
        made('item_changed', item: 'Bread', quantity: 3, actor: 'Joana'),
        made('item_removed', item: 'Milk', actor: 'Bia'),
        made('list_removed', actor: 'Ana'),
      ], (key, params) => english(key, params)).single.lines;

      expect(lines, [
        'Bia added Sausages (x4)',
        'Rui took Beer out of the cart',
        'Joana changed Bread (x3)',
        'Bia removed Milk',
        'Ana deleted this list',
      ]);
    });

    test('several of the same by one person become one line', () async {
      await setUpService();

      final lines = buildNotices([
        made('item_removed', item: 'A'),
        made('item_removed', item: 'B'),
        made('item_removed', item: 'C'),
      ], (key, params) => english(key, params)).single.lines;

      expect(lines, ['Bia removed 3 items']);
    });

    test('with the app on screen it is a banner in the app, with it off screen a phone notification', () async {
      await setUpService();
      final banners = <ActivityNotice>[];
      service.onInApp = (notices) {
        banners.addAll(notices);
        return notices;
      };

      await service.deliver([made('item_added', item: 'Milk', quantity: 1)], onScreen: true);
      expect(banners.single.title, 'Barbecue');
      expect(banners.single.lines, ['Bia added Milk']);
      expect(sink.shown, isEmpty);

      await service.deliver([made('item_in_cart', item: 'Milk'), made('item_purchased', item: 'Beer')], onScreen: false);
      expect(sink.shown.single.title, 'Barbecue');
      expect(sink.shown.single.lines, ['Bia put Milk in the cart', 'Bia bought Beer']);
    });

    test('only what the person asked to hear about, and each channel can be switched off', () async {
      await setUpService(values: {'notify_cart': false, 'notify_in_app': false});
      final banners = <ActivityNotice>[];
      service.onInApp = (notices) {
        banners.addAll(notices);
        return notices;
      };

      // the cart is not wanted; the banner is switched off
      expect(await service.deliver([made('item_in_cart', item: 'Milk')], onScreen: false), 0);
      expect(await service.deliver([made('item_added', item: 'Milk')], onScreen: true), 0);
      expect(banners, isEmpty);

      // adding is wanted, as a phone notification
      expect(await service.deliver([made('item_added', item: 'Milk')], onScreen: false), 1);
      expect(sink.shown.single.lines, ['Bia added Milk']);
    });
  });

  group('a sound for each kind of thing', () {
    ActivityEvent made(String kind) => ActivityEvent(id: 0, kind: kind, actor: 'Bia', listUuid: 'list-1', list: 'Barbecue', item: 'Milk', quantity: 1);

    test('each kind has its own sound, and the cart and the purchase are not the same', () {
      expect(NotificationService.soundOf('item_added'), 'added');
      expect(NotificationService.soundOf('list_created'), 'added');
      expect(NotificationService.soundOf('item_in_cart'), 'cart');
      expect(NotificationService.soundOf('item_returned'), 'cart');
      expect(NotificationService.soundOf('item_purchased'), 'bought');
      expect(NotificationService.soundOf('item_changed'), 'changes');
      expect(NotificationService.soundOf('item_removed'), 'changes');
      expect(NotificationService.soundOf('list_removed'), 'changes');
      expect(NotificationService.sounds.toSet().length, 4);
    });

    test('a phone notification asks for the sound (and channel) of what happened', () async {
      await setUpService();

      await service.deliver([made('item_purchased')], onScreen: false);
      await service.deliver([made('item_removed')], onScreen: false);

      expect(sink.shown.map((n) => n.sound), ['bought', 'changes']);
      expect(sink.shown.first.channelName, 'Purchases');
    });

    test('a banner in the app plays the sound, but not when it was not shown', () async {
      await setUpService();

      service.onInApp = (notices) => notices;
      await service.deliver([made('item_in_cart')], onScreen: true);
      expect(sink.played, ['cart']);

      service.onInApp = (notices) => const []; // (the person is looking at that list)
      await service.deliver([made('item_added')], onScreen: true);
      expect(sink.played, ['cart']);
    });
  });

  test('who did it is told with the family name after their own', () async {
    await setUpService(displayName: (name) => '$name Silva');

    await service.deliver([
      ActivityEvent(id: 1, kind: 'item_added', actor: 'Bia', listUuid: 'l', list: 'Barbecue', item: 'Milk', quantity: 1),
    ], onScreen: false);

    expect(sink.shown.single.lines, ['Bia Silva added Milk']);
  });
}
