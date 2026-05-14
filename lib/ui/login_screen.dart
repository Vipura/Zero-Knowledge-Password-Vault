import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cryptography/cryptography.dart';
import '../services/crypto_service.dart';
import '../services/database_service.dart';
import '../utils/app_theme.dart';
import '../main.dart';

class LoginScreen extends StatefulWidget {
  final SessionManager sessionManager;
  const LoginScreen({super.key, required this.sessionManager});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _cryptoService = CryptoService();
  bool _isLoading = false;
  bool _obscurePassword = true;
  late AnimationController _animController;
  late Animation<double> _fadeIn;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeIn = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _unlock() async {
    if (_passwordController.text.isEmpty) return;

    setState(() => _isLoading = true);

    try {
      final dbService = DatabaseService.instance;
      List<int>? storedSalt = await dbService.getSalt();

      if (storedSalt != null) {
        final derivedKey = await _cryptoService.deriveKey(
            _passwordController.text, storedSalt);

        final ciphertext = await dbService.getConfig('verify_ciphertext');
        final nonce = await dbService.getConfig('verify_nonce');
        final mac = await dbService.getConfig('verify_mac');

        if (ciphertext != null && nonce != null && mac != null) {
          final box = SecretBox(
            base64Decode(ciphertext),
            nonce: base64Decode(nonce),
            mac: Mac(base64Decode(mac)),
          );

          try {
            final verifyText =
                await _cryptoService.decryptPassword(box, derivedKey);
            if (verifyText == "ZK_VAULT_VALID") {
              widget.sessionManager.unlock(derivedKey);
            } else {
              throw Exception('Invalid password validation payload.');
            }
          } catch (_) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Incorrect Master Password!',
                      style: AppTextStyles.body
                          .copyWith(color: AppColors.textPrimary)),
                  backgroundColor: AppColors.error.withValues(alpha: 0.9),
                ),
              );
            }
          }
        }
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: FadeTransition(
        opacity: _fadeIn,
        child: Center(
          ),
        ),
      ),
    );
  }
}
