import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

import '../data/api_client.dart';
import '../data/local_db.dart';
import '../data/names.dart';
import 'auth_state.dart';
import 'content_service.dart';
import 'notification_service.dart';
import 'settings_state.dart';

const _taskName = 'check-activity';
const _uniqueName = 'familyshopper-activity';

/// Set (by the "Close" button of the notification that keeps the app alive) when the person closed the
/// app completely: nothing runs, not even the scheduled checks, until they open the app again.
const closedByUserKey = 'closed_by_user';

/// Starts Android's scheduled work, which runs [backgroundDispatcher] about every 15 minutes
/// (the shortest it allows) while there is a connection, even with the app closed.
Future<void> scheduleBackgroundChecks() async {
  if (!Platform.isAndroid) return;

  await Workmanager().initialize(backgroundDispatcher);
  await Workmanager().registerPeriodicTask(
    _uniqueName,
    _taskName,
    frequency: const Duration(minutes: 15),
    constraints: Constraints(networkType: NetworkType.connected),
    existingWorkPolicy: ExistingPeriodicWorkPolicy.update,
  );
}

/// Signed out: nothing to look for any more.
Future<void> cancelBackgroundChecks() async {
  if (!Platform.isAndroid) return;

  await Workmanager().initialize(backgroundDispatcher);
  await Workmanager().cancelByUniqueName(_uniqueName);
}

/// Runs in its own isolate, without the app: it opens the same local database and token
/// the app uses, asks the server what is new and shows a notification for it.
@pragma('vm:entry-point')
void backgroundDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    WidgetsFlutterBinding.ensureInitialized();

    try {
      await runBackgroundCheck();
    } catch (_) {
      // never fail loudly: the next run tries again
    }

    return true;
  });
}

Future<int> runBackgroundCheck() async {
  final prefs = await SharedPreferences.getInstance();
  if (prefs.getBool(NotificationService.enabledKey) == false) return 0;
  if (prefs.getBool(closedByUserKey) == true) return 0;

  final token = await const FlutterSecureStorage().read(key: AuthState.tokenKey);
  if (token == null) return 0;

  // Not closed afterwards: sqflite shares one connection per file within the process, and this
  // can run while the app itself is open (or paused), where closing it would kill the app's own
  // database ("database_closed" on every sync until restart). The process ending closes it.
  final db = await LocalDb.open();
  final language = prefs.getString(SettingsState.effectiveLanguageKey);
  final api = ApiClient(baseUrl: prefs.getString('server') ?? defaultServerUrl, token: token)..language = language;

  var familyName = '';
  try {
    final me = await db.getMeta('me');
    familyName = (jsonDecode(me ?? '{}')['family']?['name'] as String?) ?? '';
  } catch (_) {
    // (no name to add)
  }

  try {
    final service = NotificationService(
      store: db,
      prefs: prefs,
      content: await ContentService.load(db),
      sink: await LocalNoticeSink.create(),
      displayName: (name) => withFamilyName(name, familyName),
    );

    return await service.check(api, foreground: false);
  } finally {
    api.close();
  }
}
