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
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 36),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 60),
                // Title
                Text(
                  'UNLOCK YOUR VAULT',
                  style: AppTextStyles.heading2.copyWith(
                    letterSpacing: 2.0,
                    fontSize: 22,
                  ),
                ),
                const SizedBox(height: 48),

                // Username/Email field
                TextField(
                  controller: _usernameController,
                  style: AppTextStyles.body
                      .copyWith(color: AppColors.textPrimary),
                  decoration: AppDecorations.inputDecoration(
                    hintText: 'Username / Email',
                    prefixIcon: Icons.person_outline,
                  ),
                ),
                const SizedBox(height: 16),

                // Master Password field
                TextField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  style: AppTextStyles.body
                      .copyWith(color: AppColors.textPrimary),
                  decoration: AppDecorations.inputDecoration(
                    hintText: 'Master Password',
                    prefixIcon: Icons.lock_outline,
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        color: AppColors.textMuted,
                        size: 20,
                      ),
                      onPressed: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                  onSubmitted: (_) => _unlock(),
                ),
                const SizedBox(height: 12),

                // Helper text
                Text(
                  "This password is your master password. It's\nthis your local, private key.",
                  style: AppTextStyles.caption,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 28),

                // Unlock button
                SizedBox(
                  width: double.infinity,
                  child: _isLoading
                      ? const Center(
                          child: CircularProgressIndicator(
                              color: AppColors.primary))
                      : Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            gradient: const LinearGradient(
                              colors: [
                                AppColors.primary,
                                Color(0xFF8B5CF6),
                              ],
                            ),
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: _unlock,
                              child: Container(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  color: AppColors.background.withValues(alpha: 0.85),
                                  border: Border.all(
                                    color: AppColors.primary,
                                    width: 1.5,
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    'Unlock',
                                    style: AppTextStyles.button.copyWith(
                                      fontSize: 17,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                ),
                const SizedBox(height: 36),

                // Biometric unlock section
                Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
          ),
        ),
      ),
    );
  }
}
