import 'package:flutter/material.dart';
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
      
      // If no salt exists, this is the first setup.
      if (storedSalt == null) {
        storedSalt = _cryptoService.generateSalt();
        await dbService.saveSalt(storedSalt);
      }

      // Security Note: Derive the SecretKey purely in memory using PBKDF2 without saving the Master Password
      final derivedKey = await _cryptoService.deriveKey(_passwordController.text, storedSalt);
      widget.sessionManager.unlock(derivedKey);
    } finally {
      setState(() => _isLoading = false);
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
              const Icon(Icons.security, size: 80, color: Colors.deepPurpleAccent),
              const SizedBox(height: 20),
              const Text('Zero-Knowledge Vault', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
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
              const SizedBox(height: 20),
              _isLoading
                  ? const CircularProgressIndicator()
                  : ElevatedButton(
                      onPressed: _unlock,
                      style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
                      child: const Text('Unlock / Setup Vault'),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
