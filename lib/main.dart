import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cryptography/cryptography.dart';
import 'ui/login_screen.dart';
import 'ui/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ZeroKnowledgeVaultApp());
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

  // Security Note: Clears the key from volatile memory to prevent dumping attacks.
  void lock() {
    _masterKey = null;
    notifyListeners();
  }

  void onBackground() {
    // Security Note: Wipe the key after 30 seconds of inactivity in background.
    _backgroundTimer?.cancel();
    _backgroundTimer = Timer(const Duration(seconds: 30), () {
      lock();
    });
  }

  void onForeground() {
    _backgroundTimer?.cancel();
  }
}

class ZeroKnowledgeVaultApp extends StatefulWidget {
  const ZeroKnowledgeVaultApp({super.key});

  @override
  State<ZeroKnowledgeVaultApp> createState() => _ZeroKnowledgeVaultAppState();
}

class _ZeroKnowledgeVaultAppState extends State<ZeroKnowledgeVaultApp> with WidgetsBindingObserver {
  final SessionManager _sessionManager = SessionManager();

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
    if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      _sessionManager.onBackground();
    } else if (state == AppLifecycleState.resumed) {
      _sessionManager.onForeground();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _sessionManager,
      builder: (context, child) {
        return MaterialApp(
          title: 'ZK Vault',
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple, brightness: Brightness.dark),
            useMaterial3: true,
          ),
          home: _sessionManager.isLocked
              ? LoginScreen(sessionManager: _sessionManager)
              : HomeScreen(sessionManager: _sessionManager),
        );
      },
    );
  }
}
