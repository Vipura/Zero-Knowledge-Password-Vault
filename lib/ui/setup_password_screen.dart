import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/crypto_service.dart';
import '../services/database_service.dart';
import '../utils/app_theme.dart';
import '../main.dart';

class SetupPasswordScreen extends StatefulWidget {
  const SetupPasswordScreen({super.key});

  @override
  State<SetupPasswordScreen> createState() => _SetupPasswordScreenState();
}

class _SetupPasswordScreenState extends State<SetupPasswordScreen> {
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  final _cryptoService = CryptoService();
  bool _isLoading = false;
  bool _obscure1 = true;
  bool _obscure2 = true;

  void _setup() async {
    if (_passwordController.text.isEmpty || _confirmController.text.isEmpty) {
      return;
    }
    if (_passwordController.text != _confirmController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Passwords do not match!',
              style:
                  AppTextStyles.body.copyWith(color: AppColors.textPrimary)),
          backgroundColor: AppColors.error.withValues(alpha: 0.9),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final dbService = DatabaseService.instance;
      final storedSalt = _cryptoService.generateSalt();
      await dbService.saveSalt(storedSalt);
      final derivedKey = await _cryptoService.deriveKey(
          _passwordController.text, storedSalt);

      final verificationBox =
          await _cryptoService.encryptPassword("ZK_VAULT_VALID", derivedKey);
      await dbService.saveConfig(
          'verify_ciphertext', base64Encode(verificationBox.cipherText));
      await dbService.saveConfig(
          'verify_nonce', base64Encode(verificationBox.nonce));
      await dbService.saveConfig(
          'verify_mac', base64Encode(verificationBox.mac.bytes));

      // Since it's zero-knowledge we can just replace the whole app with main state
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
              builder: (context) => const PasswordVaultApp(isSetup: true)),
          (r) => false,
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: Text('Setup Vault', style: AppTextStyles.heading3),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Shield icon
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary.withValues(alpha: 0.1),
                  border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.3)),
                ),
                child: const Icon(Icons.shield,
                    color: AppColors.primary, size: 48),
              ),
              const SizedBox(height: 24),
              const SizedBox(height: 8),
              const Text('Make sure to remember it. If you forget it, you will permanently lose access to your local vault.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 40),
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Master Password', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _confirmController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Confirm Master Password', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 32),
              _isLoading
                  ? const CircularProgressIndicator()
                  : ElevatedButton(
                      onPressed: _setup,
                      style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(55)),
                      child: const Text('Create Master Password'),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
