import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'data/api_client.dart';
import 'data/local_db.dart';
import 'data/repository.dart';
import 'state/auth_state.dart';
import 'state/menu_service.dart';
import 'state/settings_state.dart';
import 'state/sync_service.dart';
import 'ui/screens/first_login_screen.dart';
import 'ui/screens/home_shell.dart';
import 'ui/screens/login_screen.dart';
import 'ui/theme.dart';
import 'ui/widgets/top_bar.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final settings = await SettingsState.load();
  final repository = Repository(await LocalDb.open());
  await repository.load();

  final api = ApiClient(baseUrl: settings.serverUrl);
  final auth = AuthState(api: api, repository: repository, settings: settings);
  final sync = SyncService(api: api, repository: repository, auth: auth);
  final menus = MenuService(api: api, prefs: await SharedPreferences.getInstance());

  await auth.init();

  runApp(
    MultiProvider(
      providers: [
        Provider<ApiClient>.value(value: api),
        ChangeNotifierProvider<SettingsState>.value(value: settings),
        ChangeNotifierProvider<Repository>.value(value: repository),
        ChangeNotifierProvider<AuthState>.value(value: auth),
        ChangeNotifierProvider<SyncService>.value(value: sync),
        ChangeNotifierProvider<MenuService>.value(value: menus),
      ],
      child: const ShoppingListApp(),
    ),
  );
}

class ShoppingListApp extends StatelessWidget {
  const ShoppingListApp({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsState>();

    return MaterialApp(
      title: 'Shopping List',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: settings.themeMode,
      locale: settings.locale,
      supportedLocales: [for (final code in SettingsState.supportedLanguages.keys) Locale(code)],
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
/// Also starts and stops the sync, and keeps the footer links in the chosen language.
class AppRoot extends StatefulWidget {
  const AppRoot({super.key});

  @override
  State<AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<AppRoot> with WidgetsBindingObserver {
  AuthStatus? _last;
  String? _language;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    context.read<AuthState>().addListener(_authChanged);
    context.read<SettingsState>().addListener(_languageChanged);

    final menus = context.read<MenuService>();
    final language = context.read<SettingsState>().language;
    menus.loadCached(language);
    menus.refresh(language);
    _language = language;

    WidgetsBinding.instance.addPostFrameCallback((_) => _authChanged());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    context.read<AuthState>().removeListener(_authChanged);
    context.read<SettingsState>().removeListener(_languageChanged);
    super.dispose();
  }

  void _authChanged() {
    final status = context.read<AuthState>().status;
    if (status == _last) return;
    _last = status;

    final sync = context.read<SyncService>();
    if (status == AuthStatus.signedIn) {
      sync.start();
    } else {
      sync.stop();
    }
  }

  void _languageChanged() {
    final language = context.read<SettingsState>().language;
    if (language == _language) return;
    _language = language;

    final menus = context.read<MenuService>();
    menus.loadCached(language);
    menus.refresh(language, force: true);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) context.read<SyncService>().sync();
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
