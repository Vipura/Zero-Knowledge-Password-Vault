import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cryptography/cryptography.dart';
import '../services/crypto_service.dart';
import '../services/database_service.dart';
import '../services/biometric_service.dart';
import '../utils/app_theme.dart';
import '../main.dart';

class LoginScreen extends StatefulWidget {
  final SessionManager sessionManager;
  const LoginScreen({super.key, required this.sessionManager});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  final _passwordController = TextEditingController();
  final _cryptoService = CryptoService();
  final _biometricService = BiometricService();
  bool _isLoading = false;
  bool _isBiometricLoading = false;
  bool _obscurePassword = true;
  bool _biometricAvailable = false;

  late AnimationController _animController;
  late AnimationController _biometricPulseController;
  late Animation<double> _fadeIn;
  late Animation<double> _slideUp;
  late Animation<double> _biometricPulse;

  @override
  void initState() {
    super.initState();

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _biometricPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _fadeIn = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _slideUp = Tween<double>(begin: 30, end: 0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
    );
    _biometricPulse = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(
          parent: _biometricPulseController, curve: Curves.easeInOut),
    );

    _animController.forward();
    _checkBiometrics();
  }

  @override
  void dispose() {
    _animController.dispose();
    _biometricPulseController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _checkBiometrics() async {
    final available = await _biometricService.isBiometricAvailable();
    if (mounted) setState(() => _biometricAvailable = available);
  }

  Future<void> _unlock() async {
    if (_passwordController.text.isEmpty) return;
    setState(() => _isLoading = true);

    try {
      final dbService = DatabaseService.instance;
      final storedSalt = await dbService.getSalt();

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
            if (verifyText == 'ZK_VAULT_VALID') {
              widget.sessionManager.unlock(derivedKey);
            } else {
              throw Exception('Invalid password validation payload.');
            }
          } catch (_) {
            if (mounted) {
              _showError('Incorrect Master Password!');
            }
          }
        }
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _unlockWithBiometrics() async {
    // Biometric is a gate — vault must have been set up and
    // the key is re-derived after bio success for security.
    // For this session pattern: if no key in memory, we use
    // biometrics + stored verify to re-authenticate.

    if (!_biometricAvailable) return;
    setState(() => _isBiometricLoading = true);

    try {
      final authenticated =
          await _biometricService.authenticateWithBiometrics();
      if (!authenticated || !mounted) return;

      // Biometric success — prompt user to also enter master password
      // OR if master password was already cached this session, unlock directly.
      // Show an informative snackbar guiding the user.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.fingerprint, color: AppColors.primary, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Biometric verified! Enter your Master Password to complete unlock.',
                  style: AppTextStyles.caption
                      .copyWith(color: AppColors.textPrimary),
                ),
              ),
            ],
          ),
          backgroundColor: AppColors.surface,
          duration: const Duration(seconds: 3),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
          behavior: SnackBarBehavior.floating,
        ),
      );

      // Focus the password field for fast entry after bio success
      FocusScope.of(context).requestFocus(FocusNode());
    } finally {
      if (mounted) setState(() => _isBiometricLoading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: AppTextStyles.body.copyWith(color: AppColors.textPrimary),
        ),
        backgroundColor: AppColors.error.withValues(alpha: 0.9),
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Subtle background glow
          Positioned(
            top: -80,
            left: -60,
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.primary.withValues(alpha: 0.08),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -100,
            right: -60,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.accent.withValues(alpha: 0.06),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          // Main content
          SafeArea(
            child: FadeTransition(
              opacity: _fadeIn,
              child: AnimatedBuilder(
                animation: _slideUp,
                builder: (context, child) => Transform.translate(
                  offset: Offset(0, _slideUp.value),
                  child: child,
                ),
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 48),

                        // Shield logo
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                AppColors.primary.withValues(alpha: 0.15),
                                Colors.transparent,
                              ],
                            ),
                            border: Border.all(
                              color:
                                  AppColors.primary.withValues(alpha: 0.3),
                              width: 1.5,
                            ),
                          ),
                          child: const Icon(
                            Icons.shield,
                            color: AppColors.primary,
                            size: 36,
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Title
                        Text(
                          'UNLOCK YOUR VAULT',
                          style: AppTextStyles.heading2.copyWith(
                            letterSpacing: 2.5,
                            fontSize: 20,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Zero-Knowledge · Local-First · Encrypted',
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.primary.withValues(alpha: 0.8),
                            letterSpacing: 0.5,
                            fontSize: 10,
                          ),
                        ),
                        const SizedBox(height: 40),

                        // Master Password field (only field — no email)
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
                              onPressed: () => setState(
                                  () => _obscurePassword = !_obscurePassword),
                            ),
                          ),
                          onSubmitted: (_) => _unlock(),
                        ),
                        const SizedBox(height: 10),

                        // Helper text
                        Text(
                          'Your Master Password is your local decryption key.\nIt never leaves this device.',
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
                              : _buildUnlockButton(),
                        ),
                        const SizedBox(height: 36),

                        // Biometric section
                        _buildBiometricSection(),
                        const SizedBox(height: 32),

                        // Divider
                        Row(children: [
                          Expanded(
                              child: Divider(
                                  color: AppColors.surfaceBorder)),
                          Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 12),
                            child: Text('OR',
                                style: AppTextStyles.caption.copyWith(
                                    fontSize: 10,
                                    letterSpacing: 1.2)),
                          ),
                          Expanded(
                              child: Divider(
                                  color: AppColors.surfaceBorder)),
                        ]),
                        const SizedBox(height: 20),

                        // Forgot password
                        Column(
                          children: [
                            Text(
                              'Forgot Master Password?',
                              style: AppTextStyles.label.copyWith(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'A forgotten master password cannot be recovered.\nThis is the guarantee of zero-knowledge encryption.',
                              style: AppTextStyles.caption,
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUnlockButton() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: const LinearGradient(
          colors: [AppColors.primary, Color(0xFF8B5CF6)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.3),
            blurRadius: 20,
            spreadRadius: -4,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: _unlock,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.lock_open,
                      color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'Unlock Vault',
                    style: AppTextStyles.button.copyWith(
                      color: Colors.white,
                      fontSize: 16,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBiometricSection() {
    return Column(
      children: [
        // Biometric button
        GestureDetector(
          onTap: _biometricAvailable ? _unlockWithBiometrics : null,
          child: AnimatedBuilder(
            animation: _biometricPulse,
            builder: (context, child) {
              return Transform.scale(
                scale: _biometricAvailable ? _biometricPulse.value : 1.0,
                child: child,
              );
            },
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: _biometricAvailable
                      ? AppColors.primary.withValues(alpha: 0.6)
                      : AppColors.surfaceBorder,
                  width: 1.5,
                ),
                color: _biometricAvailable
                    ? AppColors.primary.withValues(alpha: 0.08)
                    : AppColors.surface,
                boxShadow: _biometricAvailable
                    ? [
                        BoxShadow(
                          color:
                              AppColors.primary.withValues(alpha: 0.15),
                          blurRadius: 20,
                          spreadRadius: 2,
                        )
                      ]
                    : [],
              ),
              child: _isBiometricLoading
                  ? const SizedBox(
                      width: 32,
                      height: 32,
                      child: CircularProgressIndicator(
                          color: AppColors.primary, strokeWidth: 2))
                  : Icon(
                      Icons.fingerprint,
                      color: _biometricAvailable
                          ? AppColors.primary
                          : AppColors.textMuted,
                      size: 36,
                    ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Biometric Unlock',
          style: AppTextStyles.label.copyWith(
            color: _biometricAvailable
                ? AppColors.textPrimary
                : AppColors.textMuted,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          _biometricAvailable
              ? 'Fingerprint & Face ID'
              : 'Not available on this device',
          style: AppTextStyles.caption.copyWith(
            color: _biometricAvailable
                ? AppColors.textMuted
                : AppColors.surfaceBorder,
          ),
        ),
      ],
    );
  }
}
