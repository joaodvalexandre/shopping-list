import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'data/api_client.dart';
import 'data/local_db.dart';
import 'data/repository.dart';
import 'peer/identity.dart';
import 'peer/local_family.dart';
import 'peer/nearby_service.dart';
import 'peer/radio.dart';
import 'state/auth_state.dart';
import 'state/notification_service.dart';
import 'state/background_notifications.dart';
import 'state/content_service.dart';
import 'state/family_link.dart';
import 'state/settings_state.dart';
import 'state/sync_service.dart';
import 'ui/screens/first_login_screen.dart';
import 'ui/screens/home_shell.dart';
import 'ui/screens/list_detail_screen.dart';
import 'ui/screens/login_screen.dart';
import 'ui/widgets/in_app_banner.dart';
import 'ui/theme.dart';
import 'ui/widgets/top_bar.dart';

/// Lets a tapped notification open a list from outside the widget tree.
final navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final db = await LocalDb.open();
  final content = await ContentService.load(db);
  final settings = await SettingsState.load(content);
  final repository = Repository(db);
  await repository.load();

  final api = ApiClient(baseUrl: settings.serverUrl)..language = settings.language;
  settings.addListener(() => api.language = settings.language);
  final localFamily = LocalFamilyStore(db);
  final auth = AuthState(api: api, repository: repository, settings: settings, localFamily: localFamily);

  // Notifications about what others did: the plugin, and the service that asks the server
  final sink = await LocalNoticeSink.create(onTap: (uuid) => openListFromNotification(uuid, repository, auth));
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(closedByUserKey, false);
  final notifications = NotificationService(store: db, prefs: prefs, content: content, sink: sink, displayName: repository.displayName);

  // Phones of the family nearby: who this phone is, and the signed credential that proves it
  final identity = PeerIdentity(secrets: const SecureSecretStore(), store: db);
  // A local family proves who is who with this phone's key
  await repository.attachSigner(localSignerFor(identity));
  final sync = SyncService(
    keepInBackground: () => settings.keepRunning,
    api: api,
    repository: repository,
    auth: auth,
    onSynced: () async {
      // While the app is on screen the person sees changes arrive: only move the cursor.
      // Paused but still running (the process lives a while), it notifies like the background job.
      final lifecycle = WidgetsBinding.instance.lifecycleState;
      final onScreen = lifecycle == null || lifecycle == AppLifecycleState.resumed;
      await notifications.check(api, foreground: onScreen);
      // The server is reachable: the moment to renew the credential nearby phones will ask for
      await identity.refresh(api);
    },
  );

  final info = await PackageInfo.fromPlatform();
  final nearby = NearbyService(
    radio: PluginRadio(),
    identity: identity,
    repository: repository,
    prefs: prefs,
    // Only identical builds exchange data
    appVersion: '${info.version}+${info.buildNumber}',
    deviceId: _deviceId(prefs),
    trigger: Listenable.merge([sync, auth, repository]),
    // A local family has no server to reach: it always looks for its phones
    offline: () => auth.isLocal || sync.serverUnreachable,
    signedIn: () => auth.status == AuthStatus.signedIn,
    personName: () => repository.me?.name ?? '',
    localFamily: localFamily,
    // A local family keeps its phones connected with the app off screen (with a notification showing)
    keepInBackground: () => auth.isLocal,
    // What the family's other phones did: a banner in the app while it is on screen, a notification otherwise
    onNews: (result) {
      final lifecycle = WidgetsBinding.instance.lifecycleState;
      final onScreen = lifecycle == null || lifecycle == AppLifecycleState.resumed;
      notifications.deliver(result.applied.events, onScreen: onScreen);
    },
  );
  final link = FamilyLink(auth: auth, nearby: nearby, settings: settings, displayName: repository.displayName);

  // Banners inside the app, for what others do on lists the person is not looking at
  notifications.onInApp = (notices) => InAppBanner.show(
        notices,
        navigatorKey: navigatorKey,
        open: (uuid) => openListFromNotification(uuid, repository, auth),
      );

  await auth.init();

  runApp(
    MultiProvider(
      providers: [
        Provider<ApiClient>.value(value: api),
        ChangeNotifierProvider<SettingsState>.value(value: settings),
        ChangeNotifierProvider<Repository>.value(value: repository),
        ChangeNotifierProvider<AuthState>.value(value: auth),
        ChangeNotifierProvider<SyncService>.value(value: sync),
        ChangeNotifierProvider<ContentService>.value(value: content),
        Provider<NotificationService>.value(value: notifications),
        ChangeNotifierProvider<NearbyService>.value(value: nearby),
        Provider<LocalNoticeSink>.value(value: sink),
        Provider<FamilyLink>.value(value: link),
      ],
      child: const ShoppingListApp(),
    ),
  );
}

/// A short id of this installation, told to phones nearby so two of them can tell who calls whom.
String _deviceId(SharedPreferences prefs) {
  var id = prefs.getString('device_id');

  if (id == null) {
    final random = Random.secure();
    id = [for (var i = 0; i < 3; i++) random.nextInt(256).toRadixString(16).padLeft(2, '0')].join();
    prefs.setString('device_id', id);
  }

  return id;
}

/// Tapping a notification opens its list, if the person is signed in and still has it.
void openListFromNotification(String listUuid, Repository repository, AuthState auth) {
  if (auth.status != AuthStatus.signedIn || !repository.lists.any((list) => list.uuid == listUuid)) return;

  navigatorKey.currentState?.push(MaterialPageRoute(builder: (_) => ListDetailScreen(listUuid: listUuid)));
}

/// Moving between pages closes the keyboard, so the back button goes back a page instead of
/// closing a keyboard that belongs to the page just left.
class _UnfocusObserver extends NavigatorObserver {
  void _unfocus() => FocusManager.instance.primaryFocus?.unfocus();

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) => _unfocus();

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) => _unfocus();
}

class ShoppingListApp extends StatelessWidget {
  const ShoppingListApp({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsState>();

    return MaterialApp(
      navigatorKey: navigatorKey,
      navigatorObservers: [_UnfocusObserver()],
      title: 'Cestou',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: settings.themeMode,
      locale: settings.locale,
      supportedLocales: [for (final language in settings.languages) Locale(language.code)],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const AppRoot(),
    );
  }
}

/// Picks the screen for where the person is: sign in, first-login password, or the app.
/// Also starts and stops the sync, and refreshes the texts, pages and links from the server.
class AppRoot extends StatefulWidget {
  const AppRoot({super.key});

  @override
  State<AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<AppRoot> with WidgetsBindingObserver {
  AuthStatus? _last;
  bool _openedLaunchNotice = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    context.read<AuthState>().addListener(_authChanged);

    _refreshContent();

    WidgetsBinding.instance.addPostFrameCallback((_) => _authChanged());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    context.read<AuthState>().removeListener(_authChanged);
    super.dispose();
  }

  void _authChanged() {
    final status = context.read<AuthState>().status;
    if (status == _last) return;
    _last = status;

    final sync = context.read<SyncService>();
    if (status == AuthStatus.signedIn) {
      sync.start();
      _startNotifications();
    } else {
      sync.stop();
      if (status == AuthStatus.signedOut) cancelBackgroundChecks();
    }

    // Signing in or out can change which links and texts apply
    _refreshContent();
  }

  /// Ask Android's permission once, look for news in the background from now on, and
  /// open the list a notification was tapped on if that is what started the app.
  Future<void> _startNotifications() async {
    final notifications = context.read<NotificationService>();
    final sink = context.read<LocalNoticeSink>();
    final repository = context.read<Repository>();
    final auth = context.read<AuthState>();

    await notifications.askPermissionOnce();

    // News from the server: nothing to schedule for a family that has none
    if (auth.isLocal) return;

    await scheduleBackgroundChecks();

    final launched = await sink.launchedWith();
    if (launched != null && !_openedLaunchNotice) {
      _openedLaunchNotice = true;
      openListFromNotification(launched, repository, auth);
    }
  }

  /// Texts, pages and links from the server; quiet when it cannot be reached.
  /// Never for a local family, which does not talk to the server at all.
  void _refreshContent() {
    if (context.read<AuthState>().isLocal) return;
    context.read<ContentService>().refresh(context.read<ApiClient>());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // The radio for phones nearby is only on while the app is on screen
    context.read<NearbyService>().setForeground(state == AppLifecycleState.resumed);
    context.read<SyncService>().setForeground(state == AppLifecycleState.resumed);

    if (state == AppLifecycleState.resumed) {
      context.read<SyncService>().sync();
      _refreshContent();
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = context.watch<AuthState>().status;

    return switch (status) {
      AuthStatus.loading => const Scaffold(body: Center(child: AppLogo(size: 56))),
      AuthStatus.signedOut => const LoginScreen(),
      AuthStatus.mustChangePassword => const FirstLoginScreen(),
      AuthStatus.signedIn => const HomeShell(),
    };
  }
}
