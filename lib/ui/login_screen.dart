import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cryptography/cryptography.dart';
import '../services/crypto_service.dart';
import '../services/database_service.dart';
import '../main.dart';

class LoginScreen extends StatefulWidget {
  final SessionManager sessionManager;
  const LoginScreen({super.key, required this.sessionManager});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _passwordController = TextEditingController();
  final _cryptoService = CryptoService();
  bool _isLoading = false;

  void _unlock() async {
    if (_passwordController.text.isEmpty) return;
    
    setState(() => _isLoading = true);

    try {
      final dbService = DatabaseService.instance;
      List<int>? storedSalt = await dbService.getSalt();
      
      if (storedSalt != null) {
        final derivedKey = await _cryptoService.deriveKey(_passwordController.text, storedSalt);
        
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
            final verifyText = await _cryptoService.decryptPassword(box, derivedKey);
            if (verifyText == "ZK_VAULT_VALID") {
              widget.sessionManager.unlock(derivedKey);
            } else {
              throw Exception('Invalid password validation payload.');
            }
          } catch (_) {
            if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Incorrect Master Password!')));
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
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock, size: 80, color: Colors.deepPurpleAccent),
              const SizedBox(height: 20),
              const Text('Welcome Back', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 40),
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Master Password',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.password),
                ),
                onSubmitted: (_) => _unlock(),
              ),
              const SizedBox(height: 32),
              _isLoading
                  ? const CircularProgressIndicator()
                  : ElevatedButton(
                      onPressed: _unlock,
                      style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(55)),
                      child: const Text('Unlock Vault'),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
