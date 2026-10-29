import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'data/api_client.dart';
import 'data/local_db.dart';
import 'data/repository.dart';
import 'state/auth_state.dart';
import 'state/content_service.dart';
import 'state/settings_state.dart';
import 'state/sync_service.dart';
import 'ui/screens/first_login_screen.dart';
import 'ui/screens/home_shell.dart';
import 'ui/screens/login_screen.dart';
import 'ui/theme.dart';
import 'ui/widgets/top_bar.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final db = await LocalDb.open();
  final content = await ContentService.load(db);
  final settings = await SettingsState.load(content);
  final repository = Repository(db);
  await repository.load();

  final api = ApiClient(baseUrl: settings.serverUrl)..language = settings.language;
  settings.addListener(() => api.language = settings.language);
  final auth = AuthState(api: api, repository: repository, settings: settings);
  final sync = SyncService(api: api, repository: repository, auth: auth);

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
    } else {
      sync.stop();
    }

    // Signing in or out can change which links and texts apply
    _refreshContent();
  }

  /// Texts, pages and links from the server; quiet when it cannot be reached.
  void _refreshContent() => context.read<ContentService>().refresh(context.read<ApiClient>());

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
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
