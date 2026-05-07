import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/crypto_service.dart';
import '../services/database_service.dart';
import '../services/password_generator.dart';
import '../services/password_analyzer.dart';
import '../models/password_entry.dart';
import '../main.dart';

class AddPasswordScreen extends StatefulWidget {
  final SessionManager sessionManager;
  const AddPasswordScreen({super.key, required this.sessionManager});

  @override
  State<AddPasswordScreen> createState() => _AddPasswordScreenState();
}

class _AddPasswordScreenState extends State<AddPasswordScreen> {
  final _titleController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _cryptoService = CryptoService();
  final _databaseService = DatabaseService.instance;
  bool _isPasswordVisible = false;

  void _generatePassword() {
    final newPassword = PasswordGenerator.generate();
    setState(() {
      _passwordController.text = newPassword;
      _isPasswordVisible = true;
    });
  }

  void _save() async {
    if (_titleController.text.isEmpty || _passwordController.text.isEmpty) return;

    if (PasswordAnalyzer.isWeak(_passwordController.text)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Warning: This password is weak! Consider generating a stronger one.'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 3),
          )
        );
      }
    }

    final secretBox = await _cryptoService.encryptPassword(
      _passwordController.text,
      widget.sessionManager.masterKey!,
    );

    final entry = PasswordEntry(
      title: _titleController.text,
      username: _usernameController.text,
      ciphertext: base64Encode(secretBox.cipherText),
      nonce: base64Encode(secretBox.nonce),
      mac: base64Encode(secretBox.mac.bytes),
    );

    await _databaseService.create(entry);
    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Password')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: 'Title / Website'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _usernameController,
              decoration: const InputDecoration(labelText: 'Username'),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _passwordController,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      suffixIcon: IconButton(
                        icon: Icon(_isPasswordVisible ? Icons.visibility : Icons.visibility_off),
                        onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
                      ),
                    ),
                    obscureText: !_isPasswordVisible,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.autorenew),
                  onPressed: _generatePassword,
                  tooltip: 'Generate Secure Password',
                ),
              ],
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _save,
              style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
              child: const Text('Save Encrypted Password'),
            ),
          ],
        ),
      ),
    );
  }
}
