import 'package:flutter/painting.dart' show Color;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/activity.dart';
import '../data/api_client.dart';
import '../data/local_db.dart';
import 'content_service.dart';
import 'settings_state.dart';

/// Where a finished notification goes. The Android plugin in the app; a fake in tests.
abstract class NoticeSink {
  /// Android 13 and later ask before showing any notification. True when allowed.
  Future<bool> requestPermission();

  /// [lines] are the separate things that happened (shown one under the other when there are several).
  Future<void> show({required int id, required String title, required String body, required String payload, List<String> lines = const []});
}

/// Tells people what others did on the family's lists, as phone notifications.
///
/// There is no push service behind it (that needs a Firebase account): the phone asks the
/// server what happened since it last looked (`GET /activity`), when the app is in use
/// and, in the background, every 15 minutes (Android's own minimum for scheduled work).
/// What this person did themself is never reported, nor what they may not see.
class NotificationService {
  NotificationService({required this.store, required this.prefs, required this.content, required this.sink});

  final LocalStore store;
  final SharedPreferences prefs;
  final ContentService content;
  final NoticeSink sink;

  static const enabledKey = 'notifications';

  /// Which things a person wants to hear about, each a switch in Settings (all on until switched off).
  static const kindPrefs = {
    'item_added': 'notify_added',
    'list_created': 'notify_added',
    'item_in_cart': 'notify_cart',
    'item_returned': 'notify_cart',
    'item_purchased': 'notify_bought',
    'item_changed': 'notify_changes',
    'item_removed': 'notify_changes',
    'list_removed': 'notify_changes',
  };

  /// A banner inside the app, for what happens while the person is using it (on another screen than the list).
  static const inAppKey = 'notify_in_app';

  bool get inAppEnabled => prefs.getBool(inAppKey) ?? true;

  bool wantsKind(String kind) => prefs.getBool(kindPrefs[kind] ?? 'notify_added') ?? true;

  /// Where an in-app banner goes (the screen shows it).
  void Function(List<ActivityNotice> notices)? onInApp;

  /// How far into the server's feed this phone has got (cleared on sign-out with the rest of the local data).
  static const cursorKey = 'activity_cursor';

  bool get enabled => prefs.getBool(enabledKey) ?? true;

  /// Turn notifications on or off. Turning them on asks Android for permission if it
  /// has not been given; returns whether notifications will actually show.
  Future<bool> setEnabled(bool on) async {
    await prefs.setBool(enabledKey, on);
    return on ? await sink.requestPermission() : false;
  }

  /// The first time someone is signed in, ask Android's permission (once).
  Future<void> askPermissionOnce() async {
    if (!enabled || (prefs.getBool(_askedKey) ?? false)) return;

    await prefs.setBool(_askedKey, true);
    await sink.requestPermission();
  }

  static const _askedKey = 'notifications_asked';

  String _text(String key, Map<String, Object> params) =>
      content.translate(prefs.getString(SettingsState.effectiveLanguageKey) ?? content.defaultLanguage, key, params);

  /// Ask the server what is new. On screen, what is new becomes banners inside the app; off screen,
  /// each list with news gets a notification. Returns how many were shown. Quiet when the server cannot be reached.
  Future<int> check(ApiClient api, {required bool foreground}) async {
    final stored = int.tryParse(await store.getMeta(cursorKey) ?? '');

    final ActivityPage page;
    try {
      page = await api.activity(after: stored);
    } on ApiException {
      return 0;
    }

    // The first time there is nothing to compare with: start from now rather than announce the past
    if (stored == null) {
      await store.setMeta(cursorKey, '${page.lastId}');
      return 0;
    }

    final shown = await deliver(page.events, onScreen: foreground);

    if (page.lastId > stored) await store.setMeta(cursorKey, '${page.lastId}');
    return shown;
  }

  /// Tell the person what others did. With the app on screen it is a banner inside the app; with
  /// it off screen (or closed), a phone notification, one per list, with a line for each thing
  /// that was done. Only the kinds of thing this person wants to hear about. Returns how many.
  Future<int> deliver(List<ActivityEvent> all, {required bool onScreen}) async {
    final events = all.where((event) => wantsKind(event.kind)).toList();
    if (events.isEmpty) return 0;

    final notices = buildNotices(events, _text);

    if (onScreen) {
      if (!inAppEnabled || onInApp == null) return 0;
      onInApp!(notices);
      return notices.length;
    }

    if (!enabled) return 0;
    for (final notice in notices) {
      await sink.show(
        // (what an offline family tells has no number of its own: the time makes each notification its own)
        id: (notice.listUuid.hashCode ^ (notice.lastEventId != 0 ? notice.lastEventId : DateTime.now().millisecondsSinceEpoch)) & 0x7fffffff,
        title: notice.title,
        body: notice.body,
        payload: notice.listUuid,
        lines: notice.lines,
      );
    }
    return notices.length;
  }
}

/// The Android notification plugin behind [NoticeSink].
class LocalNoticeSink implements NoticeSink {
  LocalNoticeSink._(this._plugin);

  final FlutterLocalNotificationsPlugin _plugin;

  static const channelId = 'activity';

  /// [onTap] gets the payload (a list's uuid) when someone taps a notification.
  static Future<LocalNoticeSink> create({void Function(String payload)? onTap}) async {
    final plugin = FlutterLocalNotificationsPlugin();

    await plugin.initialize(
      settings: const InitializationSettings(android: AndroidInitializationSettings('ic_stat_notify')),
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload != null && payload.isNotEmpty) onTap?.call(payload);
      },
    );

    return LocalNoticeSink._(plugin);
  }

  /// The payload of the notification that started the app, if one did.
  Future<String?> launchedWith() async {
    final details = await _plugin.getNotificationAppLaunchDetails();
    return details?.didNotificationLaunchApp == true ? details!.notificationResponse?.payload : null;
  }

  @override
  Future<bool> requestPermission() async {
    final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    return await android?.requestNotificationsPermission() ?? true;
  }

  @override
  Future<void> show({required int id, required String title, required String body, required String payload, List<String> lines = const []}) {
    return _plugin.show(
      id: id,
      title: title,
      body: lines.length == 1 ? lines.first : body.split('\n').first,
      payload: payload,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          'Cestou',
          importance: Importance.high,
          priority: Priority.high,
          color: const Color(0xFF16A34A),
          // one thing: its sentence; several: a line for each, under the list's name
          styleInformation: lines.length > 1
              ? InboxStyleInformation(lines, contentTitle: title, summaryText: '${lines.length}')
              : BigTextStyleInformation(body, contentTitle: title),
        ),
      ),
    );
  }
}
