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

  // Whether the device has biometrics available
  bool _biometricAvailable = false;
  // Whether a saved key is already stored (biometric unlock ready)
  bool _biometricReady = false;

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
    _biometricPulse = Tween<double>(begin: 0.88, end: 1.0).animate(
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

  // ── Biometric availability ─────────────────────────────────────────────────

  Future<void> _checkBiometrics() async {
    final available = await _biometricService.isBiometricAvailable();
    final ready = available && await _biometricService.hasSavedKey();
    if (mounted) {
      setState(() {
        _biometricAvailable = available;
        _biometricReady = ready;
      });

      // If biometric is ready, auto-prompt after a short delay
      if (ready) {
        await Future.delayed(const Duration(milliseconds: 600));
        if (mounted) _unlockWithBiometrics();
      }
    }
  }

  // ── Master password unlock ─────────────────────────────────────────────────

  Future<void> _unlock() async {
    final password = _passwordController.text.trim();
    if (password.isEmpty) return;
    setState(() => _isLoading = true);

    try {
      final dbService = DatabaseService.instance;
      final storedSalt = await dbService.getSalt();
      if (storedSalt == null) return;

      final derivedKey =
          await _cryptoService.deriveKey(password, storedSalt);

      final ciphertext = await dbService.getConfig('verify_ciphertext');
      final nonce = await dbService.getConfig('verify_nonce');
      final mac = await dbService.getConfig('verify_mac');

      if (ciphertext == null || nonce == null || mac == null) return;

      final box = SecretBox(
        base64Decode(ciphertext),
        nonce: base64Decode(nonce),
        mac: Mac(base64Decode(mac)),
      );

      try {
        final verifyText =
            await _cryptoService.decryptPassword(box, derivedKey);
        if (verifyText != 'ZK_VAULT_VALID') {
          throw Exception('Bad payload');
        }

        // ✅ Password correct — save key bytes for future biometric unlocks
        final keyBytes = await derivedKey.extractBytes();
        if (_biometricAvailable) {
          await _biometricService.saveKeyForBiometric(keyBytes);
          if (mounted) setState(() => _biometricReady = true);
        }

        // Unlock the session
        widget.sessionManager.unlock(derivedKey);
      } on Exception {
        if (mounted) _showError('Incorrect Master Password. Try again.');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Biometric unlock ───────────────────────────────────────────────────────

  /// Full biometric unlock flow:
  /// 1. Biometric OS prompt shown
  /// 2. On success, encrypted key bytes are read from secure storage
  /// 3. SecretKey is reconstructed and used to unlock the session directly
  Future<void> _unlockWithBiometrics() async {
    if (!_biometricAvailable) return;
    setState(() => _isBiometricLoading = true);

    try {
      // loadKeyWithBiometric handles both the biometric prompt AND key retrieval
      final keyBytes = await _biometricService.loadKeyWithBiometric();

      if (keyBytes == null) {
        if (mounted) {
          _showInfo(
              'Biometric failed or no saved key. Enter your Master Password.');
        }
        return;
      }

      // Reconstruct the SecretKey from the stored bytes
      final alg = AesGcm.with256bits();
      final derivedKey = await alg.newSecretKeyFromBytes(keyBytes);

      // Verify the key is valid against the stored ciphertext
      final dbService = DatabaseService.instance;
      final ciphertext = await dbService.getConfig('verify_ciphertext');
      final nonce = await dbService.getConfig('verify_nonce');
      final mac = await dbService.getConfig('verify_mac');

      if (ciphertext == null || nonce == null || mac == null) {
        if (mounted) _showError('Vault not set up. Please use Master Password.');
        return;
      }

      final box = SecretBox(
        base64Decode(ciphertext),
        nonce: base64Decode(nonce),
        mac: Mac(base64Decode(mac)),
      );

      try {
        final verifyText =
            await _cryptoService.decryptPassword(box, derivedKey);
        if (verifyText != 'ZK_VAULT_VALID') throw Exception('Bad payload');

        // ✅ Biometric + key verification successful — unlock session
        if (mounted) widget.sessionManager.unlock(derivedKey);
      } on Exception {
        // Stored key no longer valid (e.g. master password changed)
        await _biometricService.clearSavedKey();
        if (mounted) {
          setState(() => _biometricReady = false);
          _showError(
              'Saved key is invalid. Please re-authenticate with your Master Password.');
        }
      }
    } finally {
      if (mounted) setState(() => _isBiometricLoading = false);
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message,
            style: AppTextStyles.body.copyWith(color: AppColors.textPrimary)),
        backgroundColor: AppColors.error.withValues(alpha: 0.92),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showInfo(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.info_outline,
                color: AppColors.primary, size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Text(message,
                  style: AppTextStyles.caption
                      .copyWith(color: AppColors.textPrimary)),
            ),
          ],
        ),
        backgroundColor: AppColors.surface,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Background ambient glows
          Positioned(
            top: -80,
            left: -60,
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  AppColors.primary.withValues(alpha: 0.08),
                  Colors.transparent,
                ]),
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
                gradient: RadialGradient(colors: [
                  AppColors.accent.withValues(alpha: 0.06),
                  Colors.transparent,
                ]),
              ),
            ),
          ),

          // Main content
          SafeArea(
            child: FadeTransition(
              opacity: _fadeIn,
              child: AnimatedBuilder(
                animation: _slideUp,
                builder: (_, child) =>
                    Transform.translate(offset: Offset(0, _slideUp.value), child: child),
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 48),
                        _buildShieldLogo(),
                        const SizedBox(height: 24),
                        _buildTitle(),
                        const SizedBox(height: 40),
                        _buildPasswordField(),
                        const SizedBox(height: 10),
                        _buildPasswordHint(),
                        const SizedBox(height: 28),
                        _buildUnlockButton(),
                        const SizedBox(height: 32),
                        _buildBiometricSection(),
                        const SizedBox(height: 32),
                        _buildDivider(),
                        const SizedBox(height: 20),
                        _buildForgotPasswordNote(),
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

  Widget _buildShieldLogo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [
          AppColors.primary.withValues(alpha: 0.15),
          Colors.transparent,
        ]),
        border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.3), width: 1.5),
      ),
      child:
          const Icon(Icons.shield, color: AppColors.primary, size: 36),
    );
  }

  Widget _buildTitle() {
    return Column(
      children: [
        Text(
          'UNLOCK YOUR VAULT',
          style: AppTextStyles.heading2
              .copyWith(letterSpacing: 2.5, fontSize: 20),
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
      ],
    );
  }

  Widget _buildPasswordField() {
    return TextField(
      controller: _passwordController,
      obscureText: _obscurePassword,
      style: AppTextStyles.body.copyWith(color: AppColors.textPrimary),
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
    );
  }

  Widget _buildPasswordHint() {
    return Text(
      'Your Master Password is your local decryption key.\nIt never leaves this device.',
      style: AppTextStyles.caption,
      textAlign: TextAlign.center,
    );
  }

  Widget _buildUnlockButton() {
    return SizedBox(
      width: double.infinity,
      child: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary))
          : Container(
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
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
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
    // Label changes based on setup state
    final String statusLabel;
    final String statusSub;
    if (!_biometricAvailable) {
      statusLabel = 'Biometric Unavailable';
      statusSub = 'Not supported on this device';
    } else if (_biometricReady) {
      statusLabel = 'Biometric Unlock';
      statusSub = 'Tap to unlock instantly';
    } else {
      statusLabel = 'Biometric Unlock';
      statusSub = 'Unlock once with password to enable';
    }

    return Column(
      children: [
        GestureDetector(
          onTap:
              (_biometricAvailable && _biometricReady) ? _unlockWithBiometrics : null,
          child: AnimatedBuilder(
            animation: _biometricPulse,
            builder: (_, child) => Transform.scale(
              scale: (_biometricAvailable && _biometricReady)
                  ? _biometricPulse.value
                  : 1.0,
              child: child,
            ),
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: _biometricReady
                      ? AppColors.primary.withValues(alpha: 0.65)
                      : AppColors.surfaceBorder,
                  width: 1.5,
                ),
                color: _biometricReady
                    ? AppColors.primary.withValues(alpha: 0.08)
                    : AppColors.surface,
                boxShadow: _biometricReady
                    ? [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.18),
                          blurRadius: 24,
                          spreadRadius: 2,
                        )
                      ]
                    : [],
              ),
              child: _isBiometricLoading
                  ? const SizedBox(
                      width: 36,
                      height: 36,
                      child: CircularProgressIndicator(
                          color: AppColors.primary, strokeWidth: 2))
                  : Icon(
                      Icons.fingerprint,
                      color: _biometricAvailable
                          ? _biometricReady
                              ? AppColors.primary
                              : AppColors.textMuted
                          : AppColors.surfaceBorder,
                      size: 40,
                    ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(statusLabel,
            style: AppTextStyles.label.copyWith(
              color: _biometricReady
                  ? AppColors.textPrimary
                  : AppColors.textMuted,
              fontWeight: FontWeight.w600,
            )),
        const SizedBox(height: 2),
        Text(statusSub,
            style: AppTextStyles.caption.copyWith(
              color: _biometricReady
                  ? AppColors.textMuted
                  : AppColors.surfaceBorder,
            )),
      ],
    );
  }

  Widget _buildDivider() {
    return Row(children: [
      Expanded(child: Divider(color: AppColors.surfaceBorder)),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Text('OR',
            style: AppTextStyles.caption
                .copyWith(fontSize: 10, letterSpacing: 1.2)),
      ),
      Expanded(child: Divider(color: AppColors.surfaceBorder)),
    ]);
  }

  Widget _buildForgotPasswordNote() {
    return Column(
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
    );
  }
}
