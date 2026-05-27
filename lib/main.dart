import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cryptography/cryptography.dart';
import 'ui/splash_screen.dart';
import 'ui/welcome_screen.dart';
import 'ui/login_screen.dart';
import 'ui/home_screen.dart';
import 'services/database_service.dart';
import 'utils/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final isSetup = await DatabaseService.instance.getSalt() != null;
  runApp(PasswordVaultApp(isSetup: isSetup));
}

class SessionManager extends ChangeNotifier {
  SecretKey? _masterKey;
  Timer? _backgroundTimer;

  bool get isLocked => _masterKey == null;
  SecretKey? get masterKey => _masterKey;

  void unlock(SecretKey key) {
    _masterKey = key;
    notifyListeners();
  }

  void lock() {
    _masterKey = null;
    notifyListeners();
  }

  void onBackground() {
    _backgroundTimer?.cancel();
    _backgroundTimer = Timer(const Duration(seconds: 30), () {
      lock();
    });
  }

  void onForeground() {
    _backgroundTimer?.cancel();
  }
}

class PasswordVaultApp extends StatefulWidget {
  final bool isSetup;
  const PasswordVaultApp({super.key, required this.isSetup});

  @override
  State<PasswordVaultApp> createState() => _PasswordVaultAppState();
}

class _PasswordVaultAppState extends State<PasswordVaultApp>
    with WidgetsBindingObserver {
  final SessionManager _sessionManager = SessionManager();
  bool _showSplash = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _sessionManager.onBackground();
    } else if (state == AppLifecycleState.resumed) {
      _sessionManager.onForeground();
    }
  }

  void _onSplashComplete() {
    setState(() => _showSplash = false);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _sessionManager,
      builder: (context, child) {
        return MaterialApp(
          title: 'Zero Vault',
          debugShowCheckedModeBanner: false,
          theme: AppDecorations.buildTheme(),
          home: _showSplash
              ? SplashScreen(onComplete: _onSplashComplete)
              : _sessionManager.isLocked
                  ? (widget.isSetup
                      ? LoginScreen(sessionManager: _sessionManager)
                      : const WelcomeScreen())
                  : HomeScreen(sessionManager: _sessionManager),
        );
      },
    );
  }
}
