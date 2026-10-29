import 'package:flutter/painting.dart' show Color;
import 'package:flutter/services.dart' show MethodChannel, MissingPluginException, PlatformException;
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
  /// [sound] says what kind of thing it was (see [NotificationService.soundOf]): each kind has its own
  /// sound, and its own channel in Android's notification settings, named [channelName].
  Future<void> show({
    required int id,
    required String title,
    required String body,
    required String payload,
    List<String> lines = const [],
    String sound = 'added',
    String channelName = '',
  });

  /// Play the sound of one kind of thing (for a banner in the app, which makes no notification of its own).
  Future<void> play(String sound);
}

/// Tells people what others did on the family's lists, as phone notifications.
///
/// There is no push service behind it (that needs a Firebase account): the phone asks the
/// server what happened since it last looked (`GET /activity`), when the app is in use
/// and, in the background, every 15 minutes (Android's own minimum for scheduled work).
/// What this person did themself is never reported, nor what they may not see.
class NotificationService {
  NotificationService({required this.store, required this.prefs, required this.content, required this.sink, this.displayName});

  /// Puts the family's name after a person's ("Ana Silva"); the names as they come when null.
  final String Function(String name)? displayName;

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

  /// Which of the app's sounds goes with a kind of thing: a new item or list, the cart, a purchase, or a change.
  static const sounds = ['added', 'cart', 'bought', 'changes'];

  static String soundOf(String kind) => switch (kind) {
        'item_added' || 'list_created' => 'added',
        'item_in_cart' || 'item_returned' => 'cart',
        'item_purchased' => 'bought',
        _ => 'changes',
      };

  /// A banner inside the app, for what happens while the person is using it (on another screen than the list).
  static const inAppKey = 'notify_in_app';

  bool get inAppEnabled => prefs.getBool(inAppKey) ?? true;

  bool wantsKind(String kind) => prefs.getBool(kindPrefs[kind] ?? 'notify_added') ?? true;

  /// Where an in-app banner goes (the screen shows it). Answers which of the notices it did show:
  /// not the one for the list the person is looking at.
  List<ActivityNotice> Function(List<ActivityNotice> notices)? onInApp;

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
    final events = [
      for (final event in all)
        if (wantsKind(event.kind)) displayName == null || event.actor == null ? event : event.by(displayName!(event.actor!)),
    ];
    if (events.isEmpty) return 0;

    final notices = buildNotices(events, _text);

    if (onScreen) {
      if (!inAppEnabled || onInApp == null) return 0;
      final shown = onInApp!(notices);
      if (shown.isNotEmpty) await sink.play(soundOf(shown.last.kind));
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
        sound: soundOf(notice.kind),
        channelName: _text('app_channel_${soundOf(notice.kind)}', const {}),
      );
    }
    return notices.length;
  }
}

/// The Android notification plugin behind [NoticeSink].
class LocalNoticeSink implements NoticeSink {
  LocalNoticeSink._(this._plugin);

  final FlutterLocalNotificationsPlugin _plugin;

  static const _audio = MethodChannel('app.cestou.mobile/sound');

  /// One channel for each kind of thing, so each has its own sound (and the person can change either
  /// in Android's settings). The sound files are `res/raw/sound_<kind>.wav`.
  static String channelOf(String sound) => 'cestou_$sound';

  static const _channelNames = {
    'added': 'New items and lists',
    'cart': 'Cart',
    'bought': 'Purchases',
    'changes': 'Changes and removals',
  };

  static AndroidNotificationChannel _channel(String sound, String name) => AndroidNotificationChannel(
        channelOf(sound),
        name,
        importance: Importance.high,
        sound: RawResourceAndroidNotificationSound('sound_$sound'),
      );

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

    final android = plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    // (the one channel there used to be had a plain sound and did not pop up on every phone)
    await android?.deleteNotificationChannel(channelId: 'activity');
    for (final sound in NotificationService.sounds) {
      await android?.createNotificationChannel(_channel(sound, _channelNames[sound]!));
    }

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
  Future<void> play(String sound) async {
    try {
      await _audio.invokeMethod('play', {'sound': sound});
    } on MissingPluginException {
      // (not on the app's own screen engine: no sound, no harm)
    } on PlatformException {
      // a sound that cannot play is not worth an error
    }
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
  }) {
    return _plugin.show(
      id: id,
      title: title,
      body: lines.length == 1 ? lines.first : body.split('\n').first,
      payload: payload,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          channelOf(sound),
          channelName.isEmpty ? (_channelNames[sound] ?? 'Cestou') : channelName,
          // high is what makes it drop down from the top of the screen, with its sound
          importance: Importance.high,
          priority: Priority.high,
          playSound: true,
          sound: RawResourceAndroidNotificationSound('sound_$sound'),
          enableVibration: true,
          category: AndroidNotificationCategory.message,
          visibility: NotificationVisibility.public,
          ticker: title,
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
