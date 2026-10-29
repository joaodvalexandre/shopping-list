import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

import '../data/api_client.dart';
import '../data/local_db.dart';
import 'auth_state.dart';
import 'content_service.dart';
import 'notification_service.dart';
import 'settings_state.dart';

const _taskName = 'check-activity';
const _uniqueName = 'cestou-activity';

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

  final token = await const FlutterSecureStorage().read(key: AuthState.tokenKey);
  if (token == null) return 0;

  final db = await LocalDb.open();
  try {
    final language = prefs.getString(SettingsState.effectiveLanguageKey);
    final api = ApiClient(baseUrl: prefs.getString('server') ?? defaultServerUrl, token: token)..language = language;

    final service = NotificationService(
      store: db,
      prefs: prefs,
      content: await ContentService.load(db),
      sink: await LocalNoticeSink.create(),
    );

    return await service.check(api, foreground: false);
  } finally {
    await db.close();
  }
}
