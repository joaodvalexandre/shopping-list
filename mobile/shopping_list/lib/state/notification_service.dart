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

  Future<void> show({required int id, required String title, required String body, required String payload});
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

  /// Ask the server what is new. In the foreground the person sees it happen in the lists, so
  /// only the cursor moves; in the background each list with news gets a notification.
  /// Returns how many notifications were shown. Quiet when the server cannot be reached.
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

    var shown = 0;
    if (enabled && !foreground) {
      for (final notice in buildNotices(page.events, _text)) {
        await sink.show(
          id: (notice.listUuid.hashCode ^ notice.lastEventId) & 0x7fffffff,
          title: notice.title,
          body: notice.body,
          payload: notice.listUuid,
        );
        shown++;
      }
    }

    if (page.lastId > stored) await store.setMeta(cursorKey, '${page.lastId}');
    return shown;
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
  Future<void> show({required int id, required String title, required String body, required String payload}) {
    return _plugin.show(
      id: id,
      title: title,
      body: body,
      payload: payload,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          'Cestou',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          styleInformation: BigTextStyleInformation(body),
        ),
      ),
    );
  }
}
